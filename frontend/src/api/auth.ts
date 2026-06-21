import request from './request'

export interface LoginParams { username: string; password: string }
export interface RegisterParams { username: string; password: string; nickname: string }

export function loginApi(params: LoginParams) {
  return request.post('/auth/login', params)
}
export function registerApi(params: RegisterParams) {
  return request.post('/auth/register', params)
}
