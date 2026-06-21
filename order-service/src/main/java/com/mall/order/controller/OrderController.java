package com.mall.order.controller;

import com.alibaba.csp.sentinel.annotation.SentinelResource;
import com.alibaba.csp.sentinel.slots.block.BlockException;
import com.mall.common.dto.Result;
import com.mall.common.entity.Order;
import com.mall.order.service.OrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 订单服务 Controller
 *
 * 注意: userId 由 Gateway 的 AuthGlobalFilter 解析 JWT 后
 * 通过 X-User-Id 请求头传入，无需在请求体中传递
 *
 * Sentinel 学习重点:
 * - @SentinelResource: 声明资源点，Sentinel 可对其限流/熔断
 * - fallback: 业务异常时调用（如库存不足）
 * - blockHandler: 限流/熔断触发时调用（如 QPS 过高）
 */
@Slf4j
@RestController
@RequestMapping("/order")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    /**
     * 创建订单 — Sentinel 保护
     * POST /api/order/create
     * body: { "productId": 1, "quantity": 2, "addressId": 1 }
     *
     * blockHandler: 当 QPS 超过阈值时走降级逻辑
     */
    @PostMapping("/create")
    @SentinelResource(
        value = "createOrder",
        fallback = "createOrderFallback",
        blockHandler = "createOrderBlockHandler"
    )
    public Result<Order> createOrder(
        @RequestHeader("X-User-Id") Long userId,
        @RequestBody Map<String, Object> body
    ) {
        Long productId = Long.valueOf(body.get("productId").toString());
        Integer quantity = Integer.valueOf(body.get("quantity").toString());
        Long addressId = body.containsKey("addressId") && body.get("addressId") != null
            ? Long.valueOf(body.get("addressId").toString()) : null;
        return orderService.createOrder(userId, productId, quantity, addressId);
    }

    /**
     * 业务异常降级 — Service 抛出 BusinessException 时触发
     * 注意: fallback 方法签名必须与原方法一致(Body 类型可变)，多一个 Throwable 参数
     */
    public Result<Order> createOrderFallback(
        Long userId, Map<String, Object> body, Throwable e) {
        log.error("创建订单业务异常: userId={}, error={}", userId, e.getMessage());
        return Result.fail(e.getMessage() != null ? e.getMessage() : "下单失败，请稍后重试");
    }

    /**
     * 限流/熔断降级 — 触发 Sentinel 规则时调用
     * 注意: blockHandler 固定多一个 BlockException 参数
     */
    public Result<Order> createOrderBlockHandler(
        Long userId, Map<String, Object> body, BlockException e) {
        log.warn("创建订单被限流: userId={}", userId);
        return Result.fail(429, "系统繁忙，请稍后重试");
    }

    /**
     * 订单列表（当前用户）
     * GET /api/order/list?page=1&size=10
     */
    @GetMapping("/list")
    public Result<?> list(
        @RequestHeader("X-User-Id") Long userId,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size
    ) {
        return orderService.listUserOrders(userId, page, size);
    }

    /**
     * 订单详情
     * GET /api/order/detail/{id}
     */
    @GetMapping("/detail/{id}")
    public Result<Order> detail(
        @RequestHeader("X-User-Id") Long userId,
        @PathVariable Long id
    ) {
        return orderService.getOrderById(id, userId);
    }

    /**
     * 取消订单 — 恢复库存
     * PUT /api/order/cancel/{id}
     */
    @PutMapping("/cancel/{id}")
    public Result<String> cancel(
        @RequestHeader("X-User-Id") Long userId,
        @PathVariable Long id
    ) {
        return orderService.cancelOrder(id, userId);
    }
}
