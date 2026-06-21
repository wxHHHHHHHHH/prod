package com.mall.common.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 订单实体 — order-service 管理
 */
@Data
@TableName("mall_order")
public class Order {
    @TableId(type = IdType.ASSIGN_ID)       // 雪花算法生成分布式ID
    private Long id;
    private String orderNo;                 // 订单号（业务唯一）
    private Long userId;                    // 用户ID
    private Long productId;                 // 商品ID
    private String productName;             // 商品名称（冗余，防止商品修改后订单信息变化）
    private Integer quantity;               // 数量
    private BigDecimal unitPrice;           // 单价
    private BigDecimal totalAmount;         // 总金额
    private String status;                  // PENDING/PAID/CANCELLED/REFUNDED
    private Long addressId;                 // 收货地址ID
    private String receiverName;            // 收货人姓名快照
    private String receiverPhone;           // 收货人电话快照
    private String shippingAddress;         // 完整地址快照
    private LocalDateTime payTime;          // 支付时间
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
