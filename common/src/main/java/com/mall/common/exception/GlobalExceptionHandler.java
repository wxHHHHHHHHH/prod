package com.mall.common.exception;

import com.mall.common.dto.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Collectors;

/**
 * 全局异常处理器 — @RestControllerAdvice 拦截所有 Controller 抛出的异常
 *
 * 优先级: 子类异常 → 父类异常（Exception.class 兜底）
 *
 * 学习重点:
 * 1. @RestControllerAdvice = @ControllerAdvice + @ResponseBody（返回 JSON 而非 HTML）
 * 2. @ExceptionHandler 按异常类型精确匹配
 * 3. 最下面的 Exception handler 是安全网，防止 500 错误堆栈泄漏到前端
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // ==================== 业务异常 ====================

    /**
     * 业务异常 — Service 层主动抛出的错误
     * 如: 库存不足、用户名重复、订单状态不合法
     */
    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusinessException(BusinessException e) {
        log.warn("业务异常: code={}, message={}", e.getCode(), e.getMessage());
        return Result.fail(e.getCode(), e.getMessage());
    }

    // ==================== 参数校验异常 ====================

    /**
     * @Valid / @Validated 校验失败
     * 如: @NotBlank 字段为空、@Min 不满足最小值
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleValidationException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
            .map(err -> err.getField() + ": " + err.getDefaultMessage())
            .collect(Collectors.joining("; "));
        log.warn("参数校验失败: {}", message);
        return Result.badRequest(message);
    }

    /**
     * 请求体格式错误 — JSON 解析失败、类型不匹配
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleMessageNotReadable(HttpMessageNotReadableException e) {
        log.warn("请求体解析失败: {}", e.getMessage());
        return Result.badRequest("请求参数格式错误，请检查JSON格式");
    }

    // ==================== 兜底处理 ====================

    /**
     * 未预期的运行时异常 — 打印完整堆栈，方便排查
     * 返回 500，不泄漏异常细节到前端
     */
    @ExceptionHandler(RuntimeException.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Result<Void> handleRuntimeException(RuntimeException e) {
        log.error("系统运行时异常", e);
        return Result.fail(500, "系统内部错误，请联系管理员");
    }

    /**
     * 最终兜底 — 所有未处理的异常
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Result<Void> handleException(Exception e) {
        log.error("系统未知异常", e);
        return Result.fail(500, "系统内部错误，请联系管理员");
    }
}
