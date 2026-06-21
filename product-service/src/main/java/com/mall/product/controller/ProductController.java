package com.mall.product.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.mall.common.dto.Result;
import com.mall.common.entity.Product;
import com.mall.product.mapper.ProductMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 商品服务 Controller
 *
 * 缓存策略:
 * - 商品详情: @Cacheable key="product:{id}", 5分钟过期
 * - 商品列表: @Cacheable key="products:{page}:{size}:{category}"
 * - 库存变更: @CacheEvict 清除所有商品缓存（allEntries=true）
 *
 * 学习重点:
 * @Cacheable  — 缓存存在时直接返回缓存，不执行方法体
 * @CacheEvict  — 方法执行后清除缓存
 * allEntries   — 清空整个缓存组（因为库存变化影响列表显示）
 */
@Slf4j
@RestController
@RequestMapping("/product")
@RequiredArgsConstructor
public class ProductController {

    private final ProductMapper productMapper;

    /**
     * 商品列表 — Redis 缓存
     * 缓存 key 示例: "products:1:10:all" 或 "products:1:10:数码"
     */
    @GetMapping("/list")
    @Cacheable(
        value = "products",
        key = "#page + ':' + #size + ':' + (#category != null ? #category : 'all')",
        unless = "#result == null || #result.data == null"
    )
    public Result<Page<Product>> list(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size,
        @RequestParam(required = false) String category
    ) {
        log.info("查询商品列表: page={}, size={}, category={}", page, size, category);
        Page<Product> p = new Page<>(page, size);
        LambdaQueryWrapper<Product> qw = new LambdaQueryWrapper<>();
        qw.eq(Product::getStatus, 1);
        if (category != null) qw.eq(Product::getCategory, category);
        qw.orderByDesc(Product::getCreateTime);
        return Result.ok(productMapper.selectPage(p, qw));
    }

    /**
     * 商品详情 — Redis 缓存（Feign 调用也共享此缓存）
     * 缓存 key 示例: "product:1"
     */
    @GetMapping("/detail/{id}")
    @Cacheable(
        value = "product",
        key = "#id",
        unless = "#result == null || #result.data == null"
    )
    public Result<Map<String, Object>> getProduct(@PathVariable Long id) {
        log.info("查询商品详情: id={}", id);
        Product p = productMapper.selectById(id);
        if (p == null) return Result.fail("商品不存在");
        Map<String, Object> data = new HashMap<>();
        data.put("id", p.getId()); data.put("name", p.getName());
        data.put("price", p.getPrice()); data.put("stock", p.getStock());
        data.put("description", p.getDescription()); data.put("imageUrl", p.getImageUrl());
        return Result.ok(data);
    }

    /**
     * 扣库存 — 清除缓存（Feign 调用接口）
     * allEntries=true: 库存变化后所有商品缓存失效
     */
    @PostMapping("/deduct/{id}")
    @CacheEvict(value = {"product", "products"}, allEntries = true)
    public Result<String> deductStock(@PathVariable Long id, @RequestParam int quantity) {
        log.info("扣减库存: id={}, quantity={}", id, quantity);
        Product p = productMapper.selectById(id);
        if (p == null || p.getStatus() != 1) return Result.fail("商品不存在");
        if (p.getStock() < quantity) return Result.fail("库存不足");
        p.setStock(p.getStock() - quantity);
        productMapper.updateById(p);
        return Result.ok("ok");
    }

    /**
     * 恢复库存 — 清除缓存（取消订单时调用，Feign 接口）
     */
    @PutMapping("/restore/{id}")
    @CacheEvict(value = {"product", "products"}, allEntries = true)
    public Result<String> restoreStock(@PathVariable Long id, @RequestParam int quantity) {
        log.info("恢复库存: id={}, quantity={}", id, quantity);
        Product p = productMapper.selectById(id);
        if (p == null) return Result.fail("商品不存在");
        p.setStock(p.getStock() + quantity);
        productMapper.updateById(p);
        return Result.ok("ok");
    }
}
