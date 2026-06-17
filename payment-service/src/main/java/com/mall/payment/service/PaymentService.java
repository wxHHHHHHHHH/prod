package com.mall.payment.service;

import cn.hutool.core.date.DateUtil;
import cn.hutool.core.util.IdUtil;
import cn.hutool.crypto.SecureUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.mall.common.dto.Result;
import com.mall.payment.entity.PaymentRecord;
import com.mall.payment.mapper.PaymentMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

/**
 * 支付服务 — 模拟支付宝 / 微信支付流程
 *
 * 核心学习点：
 * 1. 支付订单创建 → 第三方请求构造 → 回调验签 → 状态更新 → 通知订单服务
 * 2. 所有真实支付网关都遵循这个模式
 * 3. 生产环境替换 createPayRequest / verifyCallback 两个方法即可接入真实支付
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentMapper paymentMapper;

    // ==================== 创建支付 ====================

    /**
     * 创建支付订单 — 生成支付链接
     * 支付宝当面付扫码 / 微信Native支付 都走这个流程
     */
    @Transactional
    public Result<Map<String, Object>> createPayment(Long userId, Long orderId, BigDecimal amount, String payType) {
        // 1. 生成支付单号
        String payNo = "PAY" + DateUtil.format(LocalDateTime.now(), "yyyyMMddHHmmss")
            + IdUtil.getSnowflakeNextIdStr().substring(12);

        // 2. 写入支付记录
        PaymentRecord record = new PaymentRecord();
        record.setPayNo(payNo);
        record.setOrderId(orderId);
        record.setUserId(userId);
        record.setAmount(amount);
        record.setPayType(payType);
        record.setStatus("PENDING");
        paymentMapper.insert(record);

        // 3. 构造第三方支付请求（模拟）
        Map<String, Object> payRequest = buildPayRequest(payType, payNo, amount);

        // 4. 返回支付链接 / 二维码数据
        Map<String, Object> result = new HashMap<>();
        result.put("payNo", payNo);
        result.put("orderId", orderId);
        result.put("amount", amount);
        result.put("payUrl", payRequest.get("payUrl"));   // 扫码链接
        result.put("qrCode", payRequest.get("qrCode"));   // 二维码数据
        result.put("expireMinutes", 30);                  // 30分钟过期
        return Result.ok(result);
    }

    /**
     * 构造第三方支付请求 — 模拟版本
     * 真实接入时替换为:
     *   AlipayTradePagePayRequest (支付宝)
     *   或 UnifiedOrderRequest (微信支付)
     */
    private Map<String, Object> buildPayRequest(String payType, String payNo, BigDecimal amount) {
        Map<String, Object> params = new HashMap<>();

        // 模拟支付链接（生产环境是真实支付宝/微信链接）
        String payUrl = switch (payType) {
            case "ALIPAY" -> "https://openapi.alipay.com/gateway.do?outTradeNo=" + payNo
                + "&totalAmount=" + amount + "&subject=商城订单";
            case "WECHAT" -> "https://api.mch.weixin.qq.com/pay/unifiedorder?outTradeNo=" + payNo
                + "&totalFee=" + amount.multiply(new BigDecimal("100")).intValue();
            default -> throw new IllegalArgumentException("不支持的支付方式: " + payType);
        };

        params.put("payUrl", payUrl);
        params.put("qrCode", payNo);  // 模拟：实际是 base64 二维码图片

        // === 签名（真实环境必须） ===
        Map<String, String> signMap = new LinkedHashMap<>();
        signMap.put("outTradeNo", payNo);
        signMap.put("totalAmount", amount.toString());
        signMap.put("timestamp", String.valueOf(System.currentTimeMillis()));
        String sign = SecureUtil.md5(signMap + "YOUR_MERCHANT_SECRET");
        params.put("sign", sign);
        params.put("signMap", signMap);

        return params;
    }

    // ==================== 支付回调处理 ====================

    /**
     * 支付回调 — 第三方支付平台异步通知
     * 支付宝 notify_url / 微信支付回调地址 指向此方法
     *
     * 安全要点:
     * 1. 验签 — 防止伪造回调
     * 2. 金额校验 — 防止金额篡改
     * 3. 幂等性 — 防止重复回调导致重复处理
     */
    @Transactional
    public String handleCallback(Map<String, String> params) {
        // 1. 验签（防止伪造请求）
        if (!verifySign(params)) {
            log.error("支付回调验签失败! params={}", params);
            return "FAIL";
        }

        String payNo = params.get("outTradeNo");
        String tradeStatus = params.get("tradeStatus");  // SUCCESS / FAIL
        String thirdPartyNo = params.get("tradeNo");     // 第三方流水号

        // 2. 幂等性检查 — 已处理的直接返回成功
        PaymentRecord record = paymentMapper.selectOne(
            new LambdaQueryWrapper<PaymentRecord>().eq(PaymentRecord::getPayNo, payNo)
        );
        if (record == null) {
            log.error("支付单不存在! payNo={}", payNo);
            return "FAIL";
        }
        if (!"PENDING".equals(record.getStatus())) {
            log.info("支付单已处理，无需重复回调! payNo={}, status={}", payNo, record.getStatus());
            return "SUCCESS";  // 幂等返回
        }

        // 3. 金额校验（防止金额被篡改）
        String callbackAmount = params.get("totalAmount");
        if (callbackAmount != null) {
            BigDecimal cbAmount = new BigDecimal(callbackAmount);
            if (cbAmount.compareTo(record.getAmount()) != 0) {
                log.error("支付金额不匹配! payNo={}, db={}, cb={}",
                    payNo, record.getAmount(), cbAmount);
                return "FAIL";
            }
        }

        // 4. 更新支付状态
        if ("SUCCESS".equals(tradeStatus)) {
            record.setStatus("SUCCESS");
            record.setThirdPartyNo(thirdPartyNo);
            record.setPayTime(LocalDateTime.now());
            paymentMapper.updateById(record);

            log.info("支付成功! payNo={}, orderId={}, amount={}",
                payNo, record.getOrderId(), record.getAmount());

            // TODO: 发送 MQ 消息通知订单服务更新订单状态
            // rocketMQTemplate.send("order-paid", payNo);

        } else {
            record.setStatus("FAIL");
            paymentMapper.updateById(record);
            log.warn("支付失败! payNo={}", payNo);
        }

        // 5. 返回给支付平台确认接收
        return "SUCCESS";
    }

    /**
     * 验证回调签名 — 模拟版本
     * 真实接入时替换为支付宝/微信各自的验签方式:
     *   AlipaySignature.rsaCheckV1() 或 WXPayUtil.isSignatureValid()
     */
    private boolean verifySign(Map<String, String> params) {
        // 生产环境用支付宝/微信官方 SDK 验签
        // 此处模拟：所有回调都视为合法
        String sign = params.get("sign");
        return sign != null && sign.length() > 0;
    }

    // ==================== 查询 & 退款 ====================

    /**
     * 查询支付状态
     */
    public Result<PaymentRecord> queryPayment(String payNo) {
        PaymentRecord record = paymentMapper.selectOne(
            new LambdaQueryWrapper<PaymentRecord>().eq(PaymentRecord::getPayNo, payNo)
        );
        if (record == null) {
            return Result.fail(404, "支付单不存在");
        }
        return Result.ok(record);
    }

    /**
     * 申请退款 — 模拟
     * 真实接入: AlipayTradeRefundRequest / RefundRequest
     */
    @Transactional
    public Result<String> refund(Long userId, String payNo, String reason) {
        PaymentRecord record = paymentMapper.selectOne(
            new LambdaQueryWrapper<PaymentRecord>()
                .eq(PaymentRecord::getPayNo, payNo)
                .eq(PaymentRecord::getUserId, userId)
        );

        if (record == null) return Result.fail(404, "支付单不存在");
        if (!"SUCCESS".equals(record.getStatus())) return Result.fail(400, "只有已支付订单可退款");

        // 模拟调用第三方退款接口
        String refundNo = "REFUND" + DateUtil.format(LocalDateTime.now(), "yyyyMMddHHmmss");
        log.info("退款申请: payNo={}, refundNo={}, reason={}", payNo, refundNo, reason);

        record.setStatus("REFUNDED");
        paymentMapper.updateById(record);

        return Result.ok("退款成功，退款单号: " + refundNo);
    }
}
