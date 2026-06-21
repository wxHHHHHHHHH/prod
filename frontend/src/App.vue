<script setup lang="ts">
import { ref } from 'vue'
import AppHeader from '@/components/AppHeader.vue'
import Toast from '@/components/Toast.vue'

// 全局 Toast — provide/inject 给子组件
const toastMsg = ref('')
const toastVisible = ref(false)
let toastTimer: number

function showToast(msg: string, duration = 2000) {
  toastMsg.value = msg
  toastVisible.value = true
  clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => { toastVisible.value = false }, duration)
}

// 提供给子组件使用
import { provide } from 'vue'
provide('showToast', showToast)
</script>

<template>
  <AppHeader />
  <main class="container">
    <router-view />
  </main>
  <Teleport to="body">
    <Toast :message="toastMsg" :visible="toastVisible" />
  </Teleport>
</template>

<style scoped>
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 20px;
}
</style>
