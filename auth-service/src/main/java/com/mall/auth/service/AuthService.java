package com.mall.auth.service;

import cn.hutool.core.lang.UUID;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.mall.auth.mapper.UserMapper;
import com.mall.common.dto.Result;
import com.mall.common.entity.User;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserMapper userMapper;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private static final String SECRET = "YourSuperSecretKeyForJWTAtLeast256Bits!!Mall2024";
    private static final long EXPIRE_MS = 7 * 24 * 60 * 60 * 1000L; // 7天

    /**
     * 用户登录 — 验证密码，签发JWT
     */
    public Result<Map<String, Object>> login(String username, String password) {
        // 1. 查用户
        User user = userMapper.selectOne(
            new LambdaQueryWrapper<User>().eq(User::getUsername, username)
        );
        if (user == null) {
            return Result.fail(400, "用户名或密码错误");
        }

        // 2. 验密 — BCrypt
        if (!encoder.matches(password, user.getPassword())) {
            return Result.fail(400, "用户名或密码错误");
        }

        // 3. 签发 JWT
        SecretKey key = Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8));
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", user.getId());
        claims.put("username", user.getUsername());

        String token = Jwts.builder()
            .claims(claims)
            .subject(username)
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + EXPIRE_MS))
            .signWith(key)
            .compact();

        // 4. 返回 token + 用户信息
        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("userId", user.getId());
        data.put("username", user.getUsername());
        data.put("nickname", user.getNickname());
        return Result.ok(data);
    }

    /**
     * 用户注册
     */
    public Result<String> register(String username, String password, String nickname) {
        // 查重
        Long count = userMapper.selectCount(
            new LambdaQueryWrapper<User>().eq(User::getUsername, username)
        );
        if (count > 0) {
            return Result.fail(400, "用户名已存在");
        }

        User user = new User();
        user.setUsername(username);
        user.setPassword(encoder.encode(password));
        user.setNickname(nickname != null ? nickname : username);
        userMapper.insert(user);

        return Result.ok("注册成功");
    }
}
