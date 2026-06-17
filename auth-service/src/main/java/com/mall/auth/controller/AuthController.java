package com.mall.auth.controller;

import com.mall.auth.service.AuthService;
import com.mall.common.dto.Result;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public Result<Map<String, Object>> login(@RequestBody Map<String, String> body) {
        return authService.login(body.get("username"), body.get("password"));
    }

    @PostMapping("/register")
    public Result<String> register(@RequestBody Map<String, String> body) {
        return authService.register(
            body.get("username"),
            body.get("password"),
            body.get("nickname")
        );
    }
}
