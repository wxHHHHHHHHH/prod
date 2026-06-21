<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { useCartStore } from '@/stores/cart'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const cart = useCartStore()
const router = useRouter()
</script>

<template>
  <header class="header">
    <div class="header-inner">
      <span class="logo" @click="router.push('/products')">🏪 Mall</span>
      <nav class="nav" v-if="auth.isLoggedIn">
        <button class="nav-btn" @click="router.push('/products')">商品</button>
        <button class="nav-btn" @click="router.push('/orders')">我的订单</button>
        <button class="nav-btn accent" @click="router.push('/cart')">
          🛒 <span v-if="cart.cartCount" class="cart-badge">{{ cart.cartCount }}</span>
        </button>
        <button class="nav-btn" @click="auth.logout()">退出</button>
      </nav>
    </div>
  </header>
</template>

<style scoped>
.header {
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  padding: 0 20px;
  position: sticky;
  top: 0;
  z-index: 100;
}
.header-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 60px;
  gap: 20px;
}
.logo {
  font-size: 20px;
  font-weight: 800;
  cursor: pointer;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  white-space: nowrap;
}
.nav { display: flex; align-items: center; gap: 4px; }
.nav-btn {
  padding: 8px 16px;
  border-radius: var(--radius-sm);
  border: none;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  font-family: inherit;
  background: transparent;
  color: var(--ink2);
  transition: all .15s;
}
.nav-btn:hover { color: var(--ink); background: var(--bg); }
.nav-btn.accent { background: var(--accent); color: #fff; font-weight: 600; }
.nav-btn.accent:hover { background: var(--accent2); }
.cart-badge {
  background: var(--warm);
  color: #fff;
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 10px;
  margin-left: -4px;
}
</style>
