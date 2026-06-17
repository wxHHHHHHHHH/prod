package com.mall.common.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 用户实体 — user-service 管理
 */
@Data
@TableName("mall_user")
public class User {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String username;        // 用户名
    private String password;        // BCrypt 加密
    private String nickname;        // 昵称
    private String phone;           // 手机号
    private String email;           // 邮箱
    private String avatar;          // 头像URL
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
    @TableLogic
    private Integer deleted;        // 0正常 1删除
}
