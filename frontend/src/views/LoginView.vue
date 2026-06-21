<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const isReg = ref(false)
const loginForm = ref({ username: '', password: '', nickname: '' })
const error = ref('')
const loading = ref(false)

async function doLogin() {
  if (!loginForm.value.username || !loginForm.value.password) {
    error.value = '请填写用户名和密码'
    return
  }
  loading.value = true
  error.value = ''
  try {
    if (isReg.value) {
      await auth.register(
        loginForm.value.username,
        loginForm.value.password,
        loginForm.value.nickname || loginForm.value.username
      )
      isReg.value = false
      error.value = ''
      alert('注册成功，请登录')
    } else {
      await auth.login(loginForm.value.username, loginForm.value.password)
    }
  } catch (e: any) {
    error.value = e.message || '操作失败'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-wrap">
    <div class="login-card">
      <h1>{{ isReg ? '注册' : '登录' }}</h1>
      <p class="sub">微服务商城 · {{ isReg ? '创建账号' : '欢迎回来' }}</p>

      <div class="form-group">
        <label>用户名</label>
        <input class="input" v-model="loginForm.username" placeholder="请输入用户名" @keyup.enter="doLogin">
      </div>

      <div class="form-group" v-if="isReg">
        <label>昵称</label>
        <input class="input" v-model="loginForm.nickname" placeholder="怎么称呼你">
      </div>

      <div class="form-group">
        <label>密码</label>
        <input class="input" v-model="loginForm.password" type="password" placeholder="请输入密码" @keyup.enter="doLogin">
      </div>

      <div v-if="error" class="error">{{ error }}</div>

      <button
        class="btn"
        :class="isReg ? 'btn-warm' : 'btn-primary'"
        @click="doLogin"
        :disabled="loading"
      >
        {{ loading ? '处理中...' : (isReg ? '注册' : '登录') }}
      </button>

      <span class="link" @click="isReg = !isReg; error = ''">
        {{ isReg ? '已有账号？去登录' : '没有账号？去注册' }}
      </span>
    </div>
  </div>
</template>

<style scoped>
.login-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 20px;
  background: linear-gradient(135deg, #f0f0ff, #fff, #fef0f0);
}
.login-card {
  background: var(--surface);
  padding: 40px;
  border-radius: var(--radius);
  box-shadow: 0 4px 24px rgba(0,0,0,.06);
  width: 100%;
  max-width: 400px;
}
.login-card h1 { font-size: 24px; font-weight: 800; text-align: center; margin-bottom: 8px; }
.sub { text-align: center; color: var(--ink3); font-size: 14px; margin-bottom: 28px; }
.form-group { margin-bottom: 16px; }
.form-group label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; color: var(--ink2); }
.input {
  width: 100%;
  padding: 12px 16px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  font-size: 15px;
  font-family: inherit;
  transition: all .15s;
  background: var(--bg);
}
.input:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(99,102,241,.1); }
.error { color: var(--danger); font-size: 13px; text-align: center; margin-bottom: 12px; }
.btn {
  width: 100%;
  padding: 13px;
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 15px;
  font-weight: 600;
  font-family: inherit;
  transition: all .15s;
}
.btn-primary { background: var(--accent); color: #fff; }
.btn-primary:hover { background: var(--accent2); }
.btn-warm { background: var(--warm); color: #fff; }
.btn-warm:hover { background: #d97706; }
.btn:disabled { opacity: .5; cursor: not-allowed; }
.link { color: var(--accent); cursor: pointer; font-size: 14px; text-align: center; display: block; margin-top: 12px; }
.link:hover { text-decoration: underline; }
</style>
