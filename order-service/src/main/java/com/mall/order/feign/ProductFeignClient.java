package com.mall.order.feign;

import com.mall.common.dto.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Feign 声明式客户端 — 调用 product-service
 * name 必须与 Nacos 注册的服务名一致
 *
 * 学习重点:
 * 1. @FeignClient(name = "服务名") — Spring Cloud 会自动从 Nacos 发现服务地址
 * 2. 方法签名与目标 Controller 保持一致（路径、参数、返回值）
 * 3. Feign 默认使用 JDK 动态代理，底层是 HttpURLConnection
 */
@FeignClient(name = "product-service")
public interface ProductFeignClient {

    /** 查询商品详情 */
    @GetMapping("/product/detail/{id}")
    Result<Map<String, Object>> getProduct(@PathVariable Long id);

    /** 扣减库存 */
    @PostMapping("/product/deduct/{id}")
    Result<String> deductStock(@PathVariable Long id, @RequestParam int quantity);

    /** 恢复库存（取消订单时调用） */
    @PutMapping("/product/restore/{id}")
    Result<String> restoreStock(@PathVariable Long id, @RequestParam int quantity);
}
