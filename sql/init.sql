-- ============================================
-- 微服务商城 — 数据库初始化脚本
-- ============================================

CREATE DATABASE IF NOT EXISTS mall
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE mall;

-- 用户表
CREATE TABLE IF NOT EXISTS mall_user (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  username    VARCHAR(50)  NOT NULL UNIQUE COMMENT '用户名',
  password    VARCHAR(200) NOT NULL COMMENT 'BCrypt加密',
  nickname    VARCHAR(50)  DEFAULT NULL COMMENT '昵称',
  phone       VARCHAR(20)  DEFAULT NULL COMMENT '手机号',
  email       VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
  avatar      VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
  create_time DATETIME     DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted     TINYINT      DEFAULT 0 COMMENT '0正常 1删除',
  INDEX idx_username (username)
) ENGINE=InnoDB COMMENT='用户表';

-- 商品表
CREATE TABLE IF NOT EXISTS mall_product (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(200)   NOT NULL COMMENT '商品名称',
  description TEXT           DEFAULT NULL COMMENT '描述',
  price       DECIMAL(10,2)  NOT NULL COMMENT '价格',
  stock       INT            DEFAULT 0 COMMENT '库存',
  image_url   VARCHAR(500)   DEFAULT NULL COMMENT '图片URL',
  category    VARCHAR(50)    DEFAULT NULL COMMENT '分类',
  status      TINYINT        DEFAULT 1 COMMENT '1上架 0下架',
  create_time DATETIME       DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='商品表';

-- 订单表（含地址快照字段）
CREATE TABLE IF NOT EXISTS mall_order (
  id               BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_no         VARCHAR(64)    NOT NULL UNIQUE COMMENT '订单号',
  user_id          BIGINT         NOT NULL COMMENT '用户ID',
  product_id       BIGINT         NOT NULL COMMENT '商品ID',
  product_name     VARCHAR(200)   DEFAULT NULL COMMENT '商品名称冗余',
  quantity         INT            NOT NULL COMMENT '数量',
  unit_price       DECIMAL(10,2)  NOT NULL COMMENT '单价',
  total_amount     DECIMAL(10,2)  NOT NULL COMMENT '总金额',
  status           VARCHAR(20)    DEFAULT 'PENDING' COMMENT 'PENDING/PAID/CANCELLED/REFUNDED',
  address_id       BIGINT         DEFAULT NULL COMMENT '收货地址ID',
  receiver_name    VARCHAR(50)    DEFAULT NULL COMMENT '收货人姓名快照',
  receiver_phone   VARCHAR(20)    DEFAULT NULL COMMENT '收货人电话快照',
  shipping_address VARCHAR(500)   DEFAULT NULL COMMENT '完整地址快照(省市区+详细)',
  pay_time         DATETIME       DEFAULT NULL COMMENT '支付时间',
  create_time      DATETIME       DEFAULT CURRENT_TIMESTAMP,
  update_time      DATETIME       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_order_no (order_no)
) ENGINE=InnoDB COMMENT='订单表';

-- 支付记录表
CREATE TABLE IF NOT EXISTS mall_payment (
  id             BIGINT AUTO_INCREMENT PRIMARY KEY,
  pay_no         VARCHAR(64)    NOT NULL UNIQUE COMMENT '支付单号',
  order_id       BIGINT         NOT NULL COMMENT '订单ID',
  user_id        BIGINT         NOT NULL COMMENT '用户ID',
  amount         DECIMAL(10,2)  NOT NULL COMMENT '支付金额',
  pay_type       VARCHAR(20)    DEFAULT 'ALIPAY' COMMENT 'ALIPAY/WECHAT/BALANCE',
  status         VARCHAR(20)    DEFAULT 'PENDING' COMMENT 'PENDING/SUCCESS/FAIL/REFUNDED',
  third_party_no VARCHAR(100)   DEFAULT NULL COMMENT '第三方流水号',
  pay_time       DATETIME       DEFAULT NULL COMMENT '支付时间',
  create_time    DATETIME       DEFAULT CURRENT_TIMESTAMP,
  update_time    DATETIME       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_order_id (order_id),
  INDEX idx_pay_no (pay_no)
) ENGINE=InnoDB COMMENT='支付记录表';

-- 收货地址表
CREATE TABLE IF NOT EXISTS mall_address (
  id             BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id        BIGINT         NOT NULL COMMENT '用户ID',
  receiver_name  VARCHAR(50)    NOT NULL COMMENT '收货人姓名',
  receiver_phone VARCHAR(20)    NOT NULL COMMENT '收货人电话',
  province       VARCHAR(50)    DEFAULT NULL COMMENT '省',
  city           VARCHAR(50)    DEFAULT NULL COMMENT '市',
  district       VARCHAR(50)    DEFAULT NULL COMMENT '区',
  detail         VARCHAR(200)   DEFAULT NULL COMMENT '详细地址',
  is_default     TINYINT        DEFAULT 0 COMMENT '是否默认: 0否 1是',
  create_time    DATETIME       DEFAULT CURRENT_TIMESTAMP,
  update_time    DATETIME       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT        DEFAULT 0 COMMENT '0正常 1删除',
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='收货地址表';

-- ============================================
-- 测试数据
-- ============================================

-- BCrypt 加密的密码: 123456
INSERT INTO mall_user (username, password, nickname) VALUES
('admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EHs', '管理员'),
('test', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EHs', '测试用户');

INSERT INTO mall_product (name, description, price, stock, category, status) VALUES
('Spring Cloud Alibaba 实战教程', '从零入门微服务，包含 Nacos/Sentinel/Seata/RocketMQ 全套', 99.00, 1000, '电子书', 1),
('Java 面试八股文 2026', '涵盖 Java基础/Spring/微服务/并发/JVM/数据库', 49.90, 500, '电子书', 1),
('波比牌机械键盘', '87键 Cherry MX 青轴 白光版', 299.00, 50, '数码', 1),
('4K 显示器 27寸', 'IPS面板 Type-C 65W反向充电', 1999.00, 20, '数码', 1),
('人体工学椅', '网布透气 4D扶手 135°后仰', 1599.00, 15, '家具', 1);

INSERT INTO mall_address (user_id, receiver_name, receiver_phone, province, city, district, detail, is_default) VALUES
(1, '管理员', '13800138000', '广东省', '深圳市', '南山区', '科技园路1号 创新大厦1201', 1),
(1, '张三', '13900139000', '浙江省', '杭州市', '余杭区', '文一西路969号', 0);
