<script setup lang="ts">
import { ref, inject } from 'vue'
import { useCartStore } from '@/stores/cart'
import { useRouter } from 'vue-router'
import { createOrder as createOrderApi } from '@/api/order'

const showToast = inject<(msg: string, duration?: number) => void>('showToast')!
const cart = useCartStore()
const router = useRouter()
const ordering = ref(false)

async function submitOrder() {
  if (cart.items.length === 0) return
  ordering.value = true
  try {
    for (const item of cart.items) {
      const res = await createOrderApi(item.id, item.quantity)
      console.log('订单创建:', res.data)
    }
    showToast('订单提交成功！')
    cart.clearCart()
    router.push('/orders')
  } catch (e: any) {
    showToast(e.message || '下单失败')
  } finally {
    ordering.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-header"><h2>购物车</h2></div>

    <div v-if="cart.items.length === 0" class="empty">
      <div class="empty-icon">🛒</div>
      <p>购物车空空如也</p>
      <button class="btn btn-primary" style="width:auto;margin-top:16px" @click="router.push('/products')">
        去逛逛
      </button>
    </div>

    <div v-for="item in cart.items" :key="item.id" class="cart-item">
      <div class="item-info">
        <strong>{{ item.name }}</strong>
        <span class="item-price">¥{{ item.price.toFixed(2) }}</span>
      </div>
      <div class="item-actions">
        <div class="qty-control">
          <button @click="cart.updateQuantity(item.id, item.quantity - 1)" :disabled="item.quantity <= 1">−</button>
          <span>{{ item.quantity }}</span>
          <button @click="cart.updateQuantity(item.id, item.quantity + 1)" :disabled="item.quantity >= item.stock">+</button>
        </div>
        <span class="item-subtotal">¥{{ (item.price * item.quantity).toFixed(2) }}</span>
        <button class="rm-btn" @click="cart.removeItem(item.id)">删除</button>
      </div>
    </div>

    <div v-if="cart.items.length > 0" class="cart-footer">
      <span>合计: <span class="total-price">¥{{ cart.cartTotal.toFixed(2) }}</span></span>
      <button class="btn btn-primary" style="width:auto;padding:12px 32px" @click="submitOrder" :disabled="ordering">
        {{ ordering ? '下单中...' : '提交订单' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.page-header { padding: 24px 0 0; }
.page-header h2 { font-size: 24px; font-weight: 800; }
.empty { padding: 60px 20px; text-align: center; color: var(--ink3); }
.empty-icon { font-size: 48px; margin-bottom: 12px; }
.cart-item {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius); padding: 16px 20px; margin-top: 12px;
}
.item-info { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.item-price { color: var(--warm); font-weight: 600; }
.item-actions { display: flex; align-items: center; gap: 16px; justify-content: flex-end; }
.item-subtotal { font-weight: 700; color: var(--warm); min-width: 80px; text-align: right; }
.qty-control { display: flex; align-items: center; gap: 8px; }
.qty-control button {
  width: 28px; height: 28px; border: 1px solid var(--border);
  border-radius: 6px; background: var(--bg); cursor: pointer;
  font-size: 16px; font-family: inherit; display: flex;
  align-items: center; justify-content: center;
  transition: all .15s;
}
.qty-control button:hover:not(:disabled) { border-color: var(--accent); color: var(--accent); }
.qty-control button:disabled { opacity: .3; cursor: not-allowed; }
.qty-control span { min-width: 24px; text-align: center; font-weight: 600; }
.rm-btn {
  background: none; border: none; color: var(--danger); cursor: pointer;
  font-size: 13px; font-family: inherit; padding: 4px 8px;
}
.rm-btn:hover { text-decoration: underline; }
.cart-footer {
  display: flex; justify-content: flex-end; align-items: center;
  gap: 16px; margin-top: 24px; padding: 16px 0;
}
.total-price { font-size: 24px; font-weight: 800; color: var(--warm); }
.total-price::before { content: '¥'; font-size: 16px; }
.btn {
  padding: 13px; border: none; border-radius: var(--radius-sm);
  cursor: pointer; font-size: 15px; font-weight: 600; font-family: inherit;
  transition: all .15s;
}
.btn-primary { background: var(--accent); color: #fff; }
.btn-primary:hover { background: var(--accent2); }
.btn:disabled { opacity: .5; cursor: not-allowed; }
</style>
