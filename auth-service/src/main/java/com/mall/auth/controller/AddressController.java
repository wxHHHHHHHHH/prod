package com.mall.auth.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.mall.auth.mapper.AddressMapper;
import com.mall.common.dto.Result;
import com.mall.common.entity.Address;
import com.mall.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 收货地址管理
 *
 * 学习重点:
 * 1. RESTful API 设计: GET(查) POST(增) PUT(改) DELETE(删)
 * 2. 业务规则: 设置默认地址时需先将其他地址取消默认
 * 3. userId 从网关传入的 X-User-Id 读取，防止用户操作他人地址
 */
@RestController
@RequestMapping("/address")
@RequiredArgsConstructor
public class AddressController {

    private final AddressMapper addressMapper;

    /**
     * 当前用户地址列表
     * GET /api/address/list
     */
    @GetMapping("/list")
    public Result<List<Address>> list(@RequestHeader("X-User-Id") Long userId) {
        LambdaQueryWrapper<Address> qw = new LambdaQueryWrapper<>();
        qw.eq(Address::getUserId, userId)
            .orderByDesc(Address::getIsDefault)  // 默认地址排最前
            .orderByDesc(Address::getCreateTime);
        return Result.ok(addressMapper.selectList(qw));
    }

    /**
     * 地址详情
     * GET /api/address/detail/{id}
     */
    @GetMapping("/detail/{id}")
    public Result<Address> detail(
        @RequestHeader("X-User-Id") Long userId,
        @PathVariable Long id
    ) {
        Address addr = addressMapper.selectById(id);
        if (addr == null) throw new BusinessException(404, "地址不存在");
        if (!addr.getUserId().equals(userId)) throw new BusinessException(403, "无权查看他人地址");
        return Result.ok(addr);
    }

    /**
     * 新增地址
     * POST /api/address
     * body: { receiverName, receiverPhone, province, city, district, detail, isDefault }
     */
    @PostMapping
    public Result<Address> create(
        @RequestHeader("X-User-Id") Long userId,
        @RequestBody Address address
    ) {
        address.setUserId(userId);
        if (address.getIsDefault() == null) address.setIsDefault(0);

        // 如果设为默认地址，先取消其他默认
        if (address.getIsDefault() == 1) {
            clearDefault(userId);
        }

        // 如果是第一个地址，自动设为默认
        Long count = addressMapper.selectCount(
            new LambdaQueryWrapper<Address>().eq(Address::getUserId, userId));
        if (count == 0) address.setIsDefault(1);

        addressMapper.insert(address);
        return Result.ok(address);
    }

    /**
     * 修改地址
     * PUT /api/address/{id}
     */
    @PutMapping("/{id}")
    public Result<Address> update(
        @RequestHeader("X-User-Id") Long userId,
        @PathVariable Long id,
        @RequestBody Address update
    ) {
        Address addr = addressMapper.selectById(id);
        if (addr == null) throw new BusinessException(404, "地址不存在");
        if (!addr.getUserId().equals(userId)) throw new BusinessException(403, "无权修改他人地址");

        // 如果改为默认，先清除其他默认
        if (update.getIsDefault() != null && update.getIsDefault() == 1) {
            clearDefault(userId);
        }

        // 只更新允许修改的字段
        if (update.getReceiverName() != null) addr.setReceiverName(update.getReceiverName());
        if (update.getReceiverPhone() != null) addr.setReceiverPhone(update.getReceiverPhone());
        if (update.getProvince() != null) addr.setProvince(update.getProvince());
        if (update.getCity() != null) addr.setCity(update.getCity());
        if (update.getDistrict() != null) addr.setDistrict(update.getDistrict());
        if (update.getDetail() != null) addr.setDetail(update.getDetail());
        if (update.getIsDefault() != null) addr.setIsDefault(update.getIsDefault());

        addressMapper.updateById(addr);
        return Result.ok(addr);
    }

    /**
     * 删除地址（逻辑删除）
     * DELETE /api/address/{id}
     */
    @DeleteMapping("/{id}")
    public Result<String> delete(
        @RequestHeader("X-User-Id") Long userId,
        @PathVariable Long id
    ) {
        Address addr = addressMapper.selectById(id);
        if (addr == null) throw new BusinessException(404, "地址不存在");
        if (!addr.getUserId().equals(userId)) throw new BusinessException(403, "无权删除他人地址");
        addressMapper.deleteById(id);  // MyBatis-Plus 逻辑删除
        return Result.ok("删除成功");
    }

    /**
     * 设为默认地址
     * PUT /api/address/{id}/default
     */
    @PutMapping("/{id}/default")
    public Result<String> setDefault(
        @RequestHeader("X-User-Id") Long userId,
        @PathVariable Long id
    ) {
        Address addr = addressMapper.selectById(id);
        if (addr == null) throw new BusinessException(404, "地址不存在");
        if (!addr.getUserId().equals(userId)) throw new BusinessException(403, "无权操作");

        clearDefault(userId);
        addr.setIsDefault(1);
        addressMapper.updateById(addr);
        return Result.ok("已设为默认地址");
    }

    /**
     * 清除用户所有默认地址
     */
    private void clearDefault(Long userId) {
        LambdaQueryWrapper<Address> qw = new LambdaQueryWrapper<>();
        qw.eq(Address::getUserId, userId).eq(Address::getIsDefault, 1);
        List<Address> defaults = addressMapper.selectList(qw);
        for (Address d : defaults) {
            d.setIsDefault(0);
            addressMapper.updateById(d);
        }
    }
}
