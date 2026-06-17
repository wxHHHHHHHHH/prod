package com.mall.product.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.mall.common.dto.Result;
import com.mall.common.entity.Product;
import com.mall.product.mapper.ProductMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/product")
@RequiredArgsConstructor
public class ProductController {

    private final ProductMapper productMapper;

    // 商品列表（无需登录）
    @GetMapping("/list")
    public Result<Page<Product>> list(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size,
        @RequestParam(required = false) String category
    ) {
        Page<Product> p = new Page<>(page, size);
        LambdaQueryWrapper<Product> qw = new LambdaQueryWrapper<>();
        qw.eq(Product::getStatus, 1);
        if (category != null) qw.eq(Product::getCategory, category);
        qw.orderByDesc(Product::getCreateTime);
        return Result.ok(productMapper.selectPage(p, qw));
    }

    // 商品详情（Feign 调用接口）
    @GetMapping("/detail/{id}")
    public Result<Map<String, Object>> getProduct(@PathVariable Long id) {
        Product p = productMapper.selectById(id);
        if (p == null) return Result.fail("商品不存在");
        Map<String, Object> data = new HashMap<>();
        data.put("id", p.getId()); data.put("name", p.getName());
        data.put("price", p.getPrice()); data.put("stock", p.getStock());
        data.put("description", p.getDescription()); data.put("imageUrl", p.getImageUrl());
        return Result.ok(data);
    }

    // 扣库存（Feign 调用接口）
    @PostMapping("/deduct/{id}")
    public Result<String> deductStock(@PathVariable Long id, @RequestParam int quantity) {
        Product p = productMapper.selectById(id);
        if (p == null || p.getStatus() != 1) return Result.fail("商品不存在");
        if (p.getStock() < quantity) return Result.fail("库存不足");
        p.setStock(p.getStock() - quantity);
        productMapper.updateById(p);
        return Result.ok("ok");
    }
}
