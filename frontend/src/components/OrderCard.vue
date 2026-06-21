<script setup lang="ts">
import type { OrderItem } from '@/stores/order'

defineProps<{ order: OrderItem }>()
const emit = defineEmits<{
  (e: 'pay', order: OrderItem): void
  (e: 'cancel', order: OrderItem): void
  (e: 'detail', order: OrderItem): void
}>()

const statusMap: Record<string, string> = {
  PENDING: '待支付',
  PAID: '已支付',
  CANCELLED: '已取消',
  REFUNDED: '已退款'
}
</script>

<template>
  <div class="order-card" @click="emit('detail', order)">
    <div class="order-header">
      <span class="order-no">{{ order.orderNo }}</span>
      <span :class="'order-status status-' + (order.status || 'PENDING')">
        {{ statusMap[order.status] || order.status }}
      </span>
    </div>
    <div>{{ order.productName }} × {{ order.quantity }}</div>
    <div class="order-footer">
      <span class="order-amount">¥{{ order.totalAmount }}</span>
      <button
        class="nav-btn accent"
        v-if="order.status === 'PENDING'"
        @click.stop="emit('pay', order)"
      >💳 去支付</button>
      <button
        class="nav-btn"
        style="color:var(--danger);font-size:12px"
        v-if="order.status === 'PENDING'"
        @click.stop="emit('cancel', order)"
      >取消</button>
    </div>
  </div>
</template>

<style scoped>
.order-card {
  background: var(--surface);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  padding: 16px 20px;
  margin-bottom: 12px;
  cursor: pointer;
  transition: all .15s;
}
.order-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,.04); }
.order-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}
.order-no { font-size: 12px; color: var(--ink3); font-family: monospace; }
.order-status {
  padding: 2px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}
.status-PENDING { background: #fef3c7; color: #92400e; }
.status-PAID { background: #d1fae5; color: #065f46; }
.status-CANCELLED { background: #fee2e2; color: #991b1b; }
.status-REFUNDED { background: #e0e7ff; color: #3730a3; }
.order-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 8px;
}
.order-amount { font-size: 18px; font-weight: 700; color: var(--warm); }
.nav-btn {
  padding: 6px 14px;
  border-radius: var(--radius-sm);
  border: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  font-family: inherit;
  background: transparent;
  color: var(--ink2);
  transition: all .15s;
}
.nav-btn.accent { background: var(--accent); color: #fff; font-weight: 600; }
.nav-btn.accent:hover { background: var(--accent2); }
</style>
