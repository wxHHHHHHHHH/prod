package com.mall.common.dto;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

/**
 * 统一响应结果 — 所有 Controller 返回此格式
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {
    private int code;       // 200 成功，其他失败
    private String message; // 提示信息
    private T data;         // 响应数据

    // === 快捷工厂方法 ===

    public static <T> Result<T> ok(T data) {
        return new Result<>(200, "success", data);
    }

    public static <T> Result<T> ok() {
        return new Result<>(200, "success", null);
    }

    public static <T> Result<T> fail(int code, String message) {
        return new Result<>(code, message, null);
    }

    public static <T> Result<T> fail(String message) {
        return new Result<>(500, message, null);
    }

    // 常用错误码
    public static <T> Result<T> unauthorized() { return fail(401, "未登录或token已过期"); }
    public static <T> Result<T> forbidden()    { return fail(403, "权限不足"); }
    public static <T> Result<T> notFound()     { return fail(404, "资源不存在"); }
    public static <T> Result<T> badRequest(String msg) { return fail(400, msg); }
}
