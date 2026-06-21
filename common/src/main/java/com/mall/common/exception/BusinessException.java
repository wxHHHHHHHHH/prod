package com.mall.common.exception;

import lombok.Getter;

/**
 * 业务异常 — Service 层抛出此异常，由 GlobalExceptionHandler 统一拦截
 *
 * 使用示例:
 *   throw new BusinessException(400, "库存不足");
 *   throw new BusinessException(404, "订单不存在");
 *   throw new BusinessException("用户名已存在");  // 默认 code=400
 */
@Getter
public class BusinessException extends RuntimeException {

    private final int code;

    public BusinessException(int code, String message) {
        super(message);
        this.code = code;
    }

    public BusinessException(String message) {
        super(message);
        this.code = 400;
    }

    public BusinessException(int code, String message, Throwable cause) {
        super(message, cause);
        this.code = code;
    }
}
