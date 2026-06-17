package com.mall.common.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 商品实体 — product-service 管理
 */
@Data
@TableName("mall_product")
public class Product {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;                // 商品名称
    private String description;         // 描述
    private BigDecimal price;           // 价格
    private Integer stock;              // 库存
    private String imageUrl;            // 图片URL
    private String category;            // 分类
    private Integer status;             // 1上架 0下架
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
