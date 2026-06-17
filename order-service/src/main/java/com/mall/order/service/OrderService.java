package com.mall.order.service;

import com.mall.common.dto.Result;
import com.mall.common.entity.Order;
import com.mall.common.entity.Product;
import com.mall.order.feign.ProductFeignClient;
import com.mall.order.mapper.OrderMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Map;

/**
 * 订单服务 — 创建订单 + 调用商品服务扣库存
 *
 * 分布式事务方案:
 * 1. Seata AT 模式: @GlobalTransactional 注解（最简，对业务无侵入）
 * 2. 本地消息表 + MQ: 高并发场景最终一致性
 * 3. TCC: 自定义 Try-Confirm-Cancel，适合复杂场景
 *
 * 这里使用 Seata 方案（需启动 seata-server）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderMapper orderMapper;
    private final ProductFeignClient productFeignClient;  // Feign 调用商品服务

    /**
     * 创建订单 — 分布式事务示例
     * @GlobalTransactional 确保订单创建+库存扣减要么全成功要么全回滚
     */
    // @GlobalTransactional(name = "create-order", rollbackFor = Exception.class)
    @Transactional
    public Result<Order> createOrder(Long userId, Long productId, Integer quantity) {
        // 1. Feign 远程调用商品服务——查询商品信息
        Result<Map<String, Object>> productResult = productFeignClient.getProduct(productId);
        if (productResult.getCode() != 200 || productResult.getData() == null) {
            return Result.fail("商品不存在或已下架");
        }

        Map<String, Object> productData = productResult.getData();
        String name = (String) productData.get("name");
        BigDecimal price = new BigDecimal(productData.get("price").toString());
        Integer stock = (Integer) productData.get("stock");

        // 2. 库存校验
        if (stock < quantity) {
            return Result.fail("库存不足，当前库存: " + stock);
        }

        // 3. Feign 远程调用——扣减库存
        Result<String> deductResult = productFeignClient.deductStock(productId, quantity);
        if (deductResult.getCode() != 200) {
            return Result.fail(deductResult.getMessage());
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
        orderMapper.insert(order);

        log.info("订单创建成功: orderId={}, orderNo={}, userId={}, amount={}",
            order.getId(), order.getOrderNo(), userId, order.getTotalAmount());

        return Result.ok(order);
    }

    // ... getOrderById, listUserOrders, cancelOrder 等方法省略（完整代码见项目文件）
}
