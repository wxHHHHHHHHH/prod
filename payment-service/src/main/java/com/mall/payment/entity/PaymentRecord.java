package com.mall.payment.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 支付记录 — 每笔支付流水
 */
@Data
@TableName("mall_payment")
public class PaymentRecord {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
    private String payNo;           // 支付单号（业务唯一）
    private Long orderId;           // 关联订单ID
    private Long userId;            // 用户ID
    private BigDecimal amount;      // 支付金额
    private String payType;         // 支付方式: ALIPAY / WECHAT / BALANCE
    private String status;          // PENDING / SUCCESS / FAIL / REFUNDED
    private String thirdPartyNo;    // 第三方支付流水号（支付宝/微信返回）
    private LocalDateTime payTime;  // 支付完成时间
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
