/**
 * Axios 实例 — 统一拦截器配置
 *
 * 学习重点:
 * 1. 请求拦截器: 自动附加 Authorization 头
 * 2. 响应拦截器: 401 时自动跳转登录
 * 3. baseURL 统一管理，切换环境只需改一处
 */
import axios from 'axios'

const API_BASE = '/api'  // Vite proxy 转发到后端

const request = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' }
})

// 请求拦截器 — 自动附加 token
request.interceptors.request.use(config => {
  const token = localStorage.getItem('mall_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器 — 统一错误处理
request.interceptors.response.use(
  response => {
    // 后端返回 Result<T> 格式: { code, message, data }
    const res = response.data
    if (res.code !== 200) {
      // 业务错误不抛异常，交给调用方处理
      return Promise.reject(new Error(res.message || '请求失败'))
    }
    return res
  },
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('mall_token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default request
