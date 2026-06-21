package com.mall.common.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 收货地址实体 — auth-service 管理
 *
 * 学习重点:
 * 1. 一对多关系: 一个用户可以有多个收货地址
 * 2. isDefault: 布尔值用 0/1 存储，MyBatis-Plus 自动映射
 * 3. @TableLogic: 逻辑删除，delete 操作变为 update deleted=1
 */
@Data
@TableName("mall_address")
public class Address {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;           // 用户ID
    private String receiverName;   // 收货人姓名
    private String receiverPhone;  // 收货人电话
    private String province;       // 省
    private String city;           // 市
    private String district;       // 区
    private String detail;         // 详细地址（街道/门牌号）
    private Integer isDefault;     // 是否默认地址: 0否 1是

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    @TableLogic
    private Integer deleted;       // 0正常 1删除
}
