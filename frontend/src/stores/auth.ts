import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { loginApi, registerApi } from '@/api/auth'
import router from '@/router'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('mall_token') || '')
  const username = ref(localStorage.getItem('mall_username') || '')

  const isLoggedIn = computed(() => !!token.value)

  async function login(user: string, pass: string) {
    const res = await loginApi({ username: user, password: pass })
    token.value = res.data.token
    username.value = res.data.username
    localStorage.setItem('mall_token', res.data.token)
    localStorage.setItem('mall_username', res.data.username)
    router.push('/products')
  }

  async function register(user: string, pass: string, nick: string) {
    await registerApi({ username: user, password: pass, nickname: nick })
  }

  function logout() {
    token.value = ''
    username.value = ''
    localStorage.removeItem('mall_token')
    localStorage.removeItem('mall_username')
    router.push('/login')
  }

  return { token, username, isLoggedIn, login, register, logout }
})
