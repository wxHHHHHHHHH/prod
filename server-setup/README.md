# 服务器部署指南

## 1. 上传到服务器

```bash
scp -r server-setup user@47.108.130.167:~/services/
```

## 2. 一键部署

```bash
ssh user@47.108.130.167
chmod +x ~/services/deploy.sh
cd ~/services && bash deploy.sh
```

首次运行会：
- 生成随机 5 位数端口 → 保存到 `.env`
- Docker 拉取 Nacos + MySQL + Redis
- 从 GitHub 拉取代码 → Maven 编译 → 启动 5 个微服务
- 防火墙自动放行

## 3. 常用命令

| 命令 | 说明 |
|------|------|
| `bash deploy.sh` | 部署全部 |
| `bash deploy.sh infra` | 只部署基础组件 |
| `bash deploy.sh app` | 只编译启动应用 |
| `bash deploy.sh status` | 查看所有服务状态 |
| `bash deploy.sh stop` | 停止全部 |
| `bash deploy.sh restart app` | 重启应用 |
| `bash deploy.sh logs gateway` | 查看网关日志 |

## 4. 安全组放行

阿里云控制台 → 安全组 → 入方向放行 TCP：

| 端口 | 用途 |
|------|------|
| `8080` | API 网关 |
| `.env 中的端口` | Nacos / MySQL / Redis |

## 5. 访问地址

| 服务 | 地址 |
|------|------|
| API | http://47.108.130.167:8080 |
| Nacos | http://47.108.130.167:{随机端口}/nacos |
| 前端 | 打开 frontend/index.html |

## 6. 环境变量

部署后查看 `services-ports.env`，或者手动 source：

```bash
source ~/services/services-ports.env
```
