package com.mall.payment.controller;

import com.mall.common.dto.Result;
import com.mall.payment.entity.PaymentRecord;
import com.mall.payment.service.PaymentService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/payment")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    /**
     * 创建支付 — 前端拉起收银台
     * POST /api/payment/create
     * body: { "orderId": 1, "amount": 99.00, "payType": "ALIPAY" }
     */
    @PostMapping("/create")
    public Result<Map<String, Object>> createPayment(
        @RequestHeader("X-User-Id") Long userId,
        @RequestBody Map<String, Object> body
    ) {
        Long orderId = Long.valueOf(body.get("orderId").toString());
        BigDecimal amount = new BigDecimal(body.get("amount").toString());
        String payType = body.getOrDefault("payType", "ALIPAY").toString();
        return paymentService.createPayment(userId, orderId, amount, payType);
    }

    /**
     * 支付回调 — 第三方支付平台异步通知（无需登录）
     * POST /api/payment/callback
     */
    @PostMapping("/callback")
    public String callback(HttpServletRequest request) {
        // 将请求参数转为 Map
        Map<String, String> params = new HashMap<>();
        request.getParameterMap().forEach((k, v) -> params.put(k, v[0]));
        return paymentService.handleCallback(params);
    }

    /**
     * 查询支付状态
     * GET /api/payment/query?payNo=PAY20240101...
     */
    @GetMapping("/query")
    public Result<PaymentRecord> query(@RequestParam String payNo) {
        return paymentService.queryPayment(payNo);
    }

    /**
     * 申请退款
     * POST /api/payment/refund
     * body: { "payNo": "PAY...", "reason": "不想要了" }
     */
    @PostMapping("/refund")
    public Result<String> refund(
        @RequestHeader("X-User-Id") Long userId,
        @RequestBody Map<String, String> body
    ) {
        return paymentService.refund(userId, body.get("payNo"), body.get("reason"));
    }
}
