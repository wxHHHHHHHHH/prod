package com.mall.order.feign;

import com.mall.common.dto.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Feign 声明式客户端 — 调用 product-service
 * name 必须与 Nacos 注册的服务名一致
 */
@FeignClient(name = "product-service")
public interface ProductFeignClient {

    @GetMapping("/product/detail/{id}")
    Result<Map<String, Object>> getProduct(@PathVariable Long id);

    @PostMapping("/product/deduct/{id}")
    Result<String> deductStock(@PathVariable Long id, @RequestParam int quantity);
}
