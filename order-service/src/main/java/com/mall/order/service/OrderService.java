package com.mall.order.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.mall.common.dto.Result;
import com.mall.common.entity.Order;
import com.mall.common.exception.BusinessException;
import com.mall.order.feign.ProductFeignClient;
import com.mall.order.mapper.OrderMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Map;

/**
 * 订单服务 — 创建订单 + 库存扣减 + 取消回滚
 *
 * 分布式事务方案（进阶）:
 * 1. Seata AT 模式: @GlobalTransactional(name = "create-order", rollbackFor = Exception.class)
 * 2. 本地消息表 + MQ: 高并发场景最终一致性
 * 3. TCC: 自定义 Try-Confirm-Cancel，适合复杂场景
 *
 * 目前使用 @Transactional 本地事务 + 补偿回滚（库存恢复）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderMapper orderMapper;
    private final ProductFeignClient productFeignClient;

    /**
     * 创建订单 — 扣减库存
     * @param addressId 收货地址ID（可选，Phase 1C 完善后生效）
     */
    @Transactional
    public Result<Order> createOrder(Long userId, Long productId, Integer quantity, Long addressId) {
        // 1. Feign 远程调用商品服务——查询商品信息
        Result<Map<String, Object>> productResult = productFeignClient.getProduct(productId);
        if (productResult.getCode() != 200 || productResult.getData() == null) {
            throw new BusinessException("商品不存在或已下架");
        }

        Map<String, Object> productData = productResult.getData();
        String name = (String) productData.get("name");
        BigDecimal price = new BigDecimal(productData.get("price").toString());
        Integer stock = (Integer) productData.get("stock");

        // 2. 库存校验
        if (stock < quantity) {
            throw new BusinessException("库存不足，当前库存: " + stock);
        }

        // 3. Feign 远程调用——扣减库存
        Result<String> deductResult = productFeignClient.deductStock(productId, quantity);
        if (deductResult.getCode() != 200) {
            throw new BusinessException(deductResult.getCode(), deductResult.getMessage());
        }

        // 4. 创建订单
        Order order = new Order();
        order.setOrderNo("ORD" + System.currentTimeMillis());
        order.setUserId(userId);
        order.setProductId(productId);
        order.setProductName(name);
        order.setQuantity(quantity);
        order.setUnitPrice(price);
        order.setTotalAmount(price.multiply(BigDecimal.valueOf(quantity)));
        order.setStatus("PENDING");
        // addressId 将在 Phase 1C 完善
        orderMapper.insert(order);

        log.info("订单创建成功: orderId={}, orderNo={}, userId={}, amount={}",
            order.getId(), order.getOrderNo(), userId, order.getTotalAmount());

        return Result.ok(order);
    }

    /**
     * 用户订单列表（分页）
     */
    public Result<Page<Order>> listUserOrders(Long userId, int page, int size) {
        Page<Order> p = new Page<>(page, size);
        LambdaQueryWrapper<Order> qw = new LambdaQueryWrapper<>();
        qw.eq(Order::getUserId, userId)
            .orderByDesc(Order::getCreateTime);
        return Result.ok(orderMapper.selectPage(p, qw));
    }

    /**
     * 订单详情 — 校验归属
     */
    public Result<Order> getOrderById(Long orderId, Long userId) {
        Order order = orderMapper.selectById(orderId);
        if (order == null) {
            throw new BusinessException(404, "订单不存在");
        }
        if (!order.getUserId().equals(userId)) {
            throw new BusinessException(403, "无权查看他人订单");
        }
        return Result.ok(order);
    }

    /**
     * 取消订单 — 恢复库存
     *
     * 状态机: PENDING → CANCELLED
     * PAID 状态不允许取消（需走退款流程）
     *
     * 补偿机制: 如果扣库存成功但创建订单失败（@Transactional 回滚），
     * 库存扣减不会回滚（因为是远程调用）。
     * 需要 Seata 分布式事务或 MQ 最终一致来解决。
     */
    @Transactional
    public Result<String> cancelOrder(Long orderId, Long userId) {
        Order order = orderMapper.selectById(orderId);
        if (order == null) {
            throw new BusinessException(404, "订单不存在");
        }
        if (!order.getUserId().equals(userId)) {
            throw new BusinessException(403, "无权操作他人订单");
        }
        if (!"PENDING".equals(order.getStatus())) {
            throw new BusinessException("只能取消待支付状态的订单，当前状态: " + order.getStatus());
        }

        // 恢复库存（补偿操作）
        Result<String> restoreResult = productFeignClient.restoreStock(
            order.getProductId(), order.getQuantity());
        if (restoreResult.getCode() != 200) {
            log.error("库存恢复失败! orderId={}, productId={}, quantity={}",
                orderId, order.getProductId(), order.getQuantity());
            throw new BusinessException("取消失败，库存恢复异常，请联系客服");
        }

        order.setStatus("CANCELLED");
        orderMapper.updateById(order);

        log.info("订单取消成功: orderId={}, orderNo={}, 库存已恢复", orderId, order.getOrderNo());
        return Result.ok("订单已取消，库存已恢复");
    }
}
