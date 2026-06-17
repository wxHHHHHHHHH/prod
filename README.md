# 🏪 微服务商城 — Spring Cloud Alibaba 学习实战项目

> 边学边做的微服务架构实战项目，涵盖支付、分布式事务、服务治理全套方案

---

## 📐 架构图

```
                    ┌─────────────┐
                    │   前端 VUE   │
                    └──────┬──────┘
                           │ HTTP
                    ┌──────▼──────┐
                    │   Gateway   │  ← JWT 全局认证 + Sentinel 限流
                    │   :8080     │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
     ┌────────▼──┐  ┌─────▼────┐ ┌────▼──────┐
     │Auth Service│  │Product   │ │Order       │
     │  :8081     │  │:8083     │ │:8084       │
     │ 登录/注册  │  │商品CRUD  │ │订单+扣库存  │
     └────────────┘  └──────────┘ └─────┬──────┘
                                        │ Feign
                              ┌─────────▼──────┐
                              │ Payment Service │
                              │  :8085          │
                              │ 支付宝/微信模拟  │
                              └────────────────┘

    ┌──────────────────────────────────────────┐
    │  Nacos  :8848    服务发现 + 配置中心      │
    │  MySQL  :3306    数据持久化               │
    │  Seata          分布式事务（可选）         │
    │  Sentinel        熔断/限流/降级            │
    └──────────────────────────────────────────┘
```

---

## 🛠 技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 基础框架 | Spring Boot | 3.2.5 |
| 微服务治理 | Spring Cloud | 2023.0.1 |
| 阿里巴巴组件 | Spring Cloud Alibaba | 2023.0.1.0 |
| 服务发现+配置 | Nacos | 2.3.x |
| 服务网关 | Spring Cloud Gateway | — |
| 熔断降级 | Sentinel | 1.8.x |
| 分布式事务 | Seata | 1.8.x |
| ORM | MyBatis-Plus | 3.5.6 |
| 数据库 | MySQL | 8.0+ |
| 认证 | JWT (jjwt 0.12.5) | — |
| 密码加密 | BCrypt | — |
| 工具库 | Hutool | 5.8.27 |

---

## 🚀 快速启动

### 1. 环境准备

```bash
# 确保已安装
java -version       # JDK 17+
mysql --version     # MySQL 8.0+
mvn --version       # Maven 3.9+
```

### 2. 启动 Nacos

```bash
# 下载并启动（单机模式）
wget https://github.com/alibaba/nacos/releases/download/2.3.2/nacos-server-2.3.2.zip
unzip nacos-server-2.3.2.zip
cd nacos/bin
# Windows: startup.cmd -m standalone
# Linux:   sh startup.sh -m standalone

# 访问 http://localhost:8848/nacos 账号 nacos/nacos
```

### 3. 初始化数据库

```bash
mysql -u root -p < sql/init.sql
```

### 4. 依次启动服务

```bash
# 编译整个项目
mvn clean install -DskipTests

# 按顺序启动（每个在新终端窗口）
cd gateway         && mvn spring-boot:run   # 8080
cd auth-service    && mvn spring-boot:run   # 8081
cd product-service && mvn spring-boot:run   # 8083
cd order-service   && mvn spring-boot:run   # 8084
cd payment-service && mvn spring-boot:run   # 8085
```

### 5. 验证

```bash
# 登录获取 token
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}'

# 返回: { "code":200, "data":{ "token":"eyJ...", ... } }

# 查询商品（无需 token）
curl http://localhost:8080/api/product/list

# 创建订单（需 token）
curl -X POST http://localhost:8080/api/order/create \
  -H "Authorization: Bearer <你的token>" \
  -H "Content-Type: application/json" \
  -d '{"productId":1,"quantity":1}'

# 创建支付（需 token）
curl -X POST http://localhost:8080/api/payment/create \
  -H "Authorization: Bearer <你的token>" \
  -H "Content-Type: application/json" \
  -d '{"orderId":1,"amount":99.00,"payType":"ALIPAY"}'
```

---

## 📦 模块说明

### common — 公共模块
- `entity/` — User, Order, Product 实体（MyBatis-Plus）
- `dto/Result.java` — 统一响应封装
- 被所有微服务依赖

### gateway — API 网关 (:8080)
- 基于 Spring Cloud Gateway（WebFlux 反应式）
- `AuthGlobalFilter` — 全局 JWT 校验
- 白名单路径直接放行（登录/注册/商品浏览）
- 将 userId/username 透传给下游

### auth-service — 认证服务 (:8081)
- 登录 → BCrypt 验密 → 签发 JWT（7天有效期）
- 注册 → 用户名查重 → BCrypt 加密入库
- 自身管理 `mall_user` 表

### product-service — 商品服务 (:8083)
- 商品列表（分页+分类筛选）
- 商品详情
- Feign 接口：`getProduct()` 供订单服务远程调用
- Feign 接口：`deductStock()` 扣减库存

### order-service — 订单服务 (:8084)
- 创建订单 → Feign 调商品服务扣库存
- 支持 Seata `@GlobalTransactional` 分布式事务
- 订单列表、详情、取消

### payment-service — 支付服务 (:8085)
- **核心学习模块**
- `createPayment()` — 生成支付二维码/链接（模拟支付宝当面付流程）
- `handleCallback()` — 处理支付异步回调（验签 + 幂等 + 金额校验）
- `refund()` — 退款申请
- `queryPayment()` — 支付状态查询
- 注释标注了真实接入支付宝/微信支付的替换点

---

## 💰 支付流程详解（最重要）

```
用户下单
  → Order Service 创建订单(PENDING) + 扣库存
  → 前端请求 Payment Service /create
  → Payment Service 生成支付单 + 构造支付链接
  → 用户扫码支付（跳转支付宝/微信）
  → 支付完成 → 支付宝异步通知 /callback
  → Payment Service 验签 → 更新状态 → MQ通知Order更新
  → Order Service 将订单改为 PAID
```

**模拟 vs 真实接入：**
| 步骤 | 模拟代码 | 真实替换 |
|------|----------|----------|
| 构造支付请求 | `buildPayRequest()` | 支付宝 `AlipayTradePagePayRequest` / 微信 `UnifiedOrderRequest` |
| 验签 | `verifySign()` | 支付宝 `AlipaySignature.rsaCheckV1()` / 微信 `WXPayUtil.isSignatureValid()` |
| 回调处理 | `handleCallback()` | 逻辑完全相同，验签+幂等+金额校验不变 |

---

## 📚 学习路线（按顺序）

1. ✅ **启动 Nacos**，理解注册中心如何管理服务
2. ✅ **网关 + 认证**，理解 JWT 无状态认证和网关统一鉴权
3. ✅ **商品服务**，理解 Feign 声明式远程调用
4. ✅ **订单服务**，理解跨服务调用 + 分布式事务
5. ✅ **支付服务**，理解第三方支付回调模式
6. 🚧 **Sentinel 接入**，理解熔断/限流/降级
7. 🚧 **Seata 接入**，理解 AT/TCC 分布式事务
8. 🚧 **RocketMQ 接入**，理解异步解耦

---

## 🔧 扩展方向

- [ ] 接入真实支付宝沙箱环境
- [ ] 接入 Redis 缓存商品列表
- [ ] RocketMQ 异步通知订单状态变更
- [ ] 分布式链路追踪（Sleuth + Zipkin）
- [ ] Docker Compose 一键部署
- [ ] K8s 部署配置
