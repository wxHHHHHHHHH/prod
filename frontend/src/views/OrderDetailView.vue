<script setup lang="ts">
import { ref, inject, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getOrderDetail, cancelOrder as cancelOrderApi } from '@/api/order'
import type { OrderItem } from '@/stores/order'

const showToast = inject<(msg: string, duration?: number) => void>('showToast')!
const route = useRoute()
const router = useRouter()
const order = ref<OrderItem | null>(null)
const loading = ref(true)

const statusMap: Record<string, string> = {
  PENDING: '待支付', PAID: '已支付', CANCELLED: '已取消', REFUNDED: '已退款'
}

onMounted(async () => {
  try {
    const id = Number(route.params.id)
    const res = await getOrderDetail(id)
    order.value = res.data
  } catch (e: any) {
    showToast('加载订单失败')
  } finally {
    loading.value = false
  }
})

async function cancel() {
  if (!order.value || !confirm('确认取消此订单？')) return
  try {
    await cancelOrderApi(order.value.id)
    order.value.status = 'CANCELLED'
    showToast('订单已取消，库存已恢复')
  } catch (e: any) {
    showToast(e.message || '取消失败')
  }
}
</script>

<template>
  <div>
    <div class="page-header">
      <button class="back-btn" @click="router.push('/orders')">← 返回</button>
      <h2>订单详情</h2>
    </div>

    <div v-if="loading" class="spin"></div>

    <div v-if="!loading && order" class="detail-card">
      <div class="detail-row">
        <span class="label">订单号</span>
        <span class="value mono">{{ order.orderNo }}</span>
      </div>
      <div class="detail-row">
        <span class="label">状态</span>
        <span :class="'status status-' + order.status">{{ statusMap[order.status] || order.status }}</span>
      </div>
      <div class="divider"></div>
      <div class="detail-row">
        <span class="label">商品</span>
        <span class="value">{{ order.productName }}</span>
      </div>
      <div class="detail-row">
        <span class="label">数量</span>
        <span class="value">{{ order.quantity }}</span>
      </div>
      <div class="detail-row">
        <span class="label">单价</span>
        <span class="value">¥{{ order.unitPrice }}</span>
      </div>
      <div class="detail-row">
        <span class="label">总金额</span>
        <span class="value amount">¥{{ order.totalAmount }}</span>
      </div>
      <div class="divider"></div>
      <div class="detail-row">
        <span class="label">创建时间</span>
        <span class="value">{{ order.createTime }}</span>
      </div>
      <div class="detail-row" v-if="order.payTime">
        <span class="label">支付时间</span>
        <span class="value">{{ order.payTime }}</span>
      </div>

      <button
        v-if="order.status === 'PENDING'"
        class="btn btn-danger" style="margin-top:20px"
        @click="cancel"
      >取消订单</button>
    </div>
  </div>
</template>

<style scoped>
.page-header {
  padding: 24px 0 0;
  display: flex;
  align-items: center;
  gap: 16px;
}
.page-header h2 { font-size: 24px; font-weight: 800; }
.back-btn {
  background: none; border: 1px solid var(--border);
  border-radius: var(--radius-sm); padding: 6px 14px;
  cursor: pointer; font-size: 14px; font-family: inherit;
  color: var(--ink2); transition: all .15s;
}
.back-btn:hover { border-color: var(--ink2); color: var(--ink); }
.spin {
  width: 36px; height: 36px;
  border: 3px solid var(--border);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin .8s linear infinite;
  margin: 40px auto;
}
@keyframes spin { to { transform: rotate(360deg) } }
.detail-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 24px;
  margin-top: 20px;
}
.detail-row {
  display: flex;
  justify-content: space-between;
  padding: 10px 0;
}
.label { color: var(--ink3); font-size: 14px; }
.value { font-weight: 600; }
.mono { font-family: monospace; font-size: 13px; }
.amount { font-size: 20px; font-weight: 800; color: var(--warm); }
.amount::before { content: '¥'; font-size: 14px; }
.divider { border-top: 1px solid var(--border); margin: 8px 0; }
.status {
  padding: 3px 12px;
  border-radius: 12px;
  font-size: 13px;
  font-weight: 600;
}
.status-PENDING { background: #fef3c7; color: #92400e; }
.status-PAID { background: #d1fae5; color: #065f46; }
.status-CANCELLED { background: #fee2e2; color: #991b1b; }
.status-REFUNDED { background: #e0e7ff; color: #3730a3; }
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
.btn-danger { background: var(--danger); color: #fff; }
.btn-danger:hover { opacity: .9; }
</style>
