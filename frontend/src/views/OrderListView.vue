<script setup lang="ts">
import { ref, inject, onMounted } from 'vue'
import { useOrderStore, type OrderItem } from '@/stores/order'
import { useRouter } from 'vue-router'
import OrderCard from '@/components/OrderCard.vue'
import PaymentModal from '@/components/PaymentModal.vue'

const showToast = inject<(msg: string, duration?: number) => void>('showToast')!
const orderStore = useOrderStore()
const router = useRouter()

const payingOrder = ref<OrderItem | null>(null)
const paying = ref(false)

onMounted(() => { orderStore.fetchOrders() })

function goDetail(order: OrderItem) {
  router.push(`/orders/${order.id}`)
}

function openPay(order: OrderItem) {
  payingOrder.value = order
  paying.value = true
}

async function handleCancel(order: OrderItem) {
  if (!confirm('确认取消此订单？')) return
  try {
    await orderStore.cancelOrder(order.id)
    showToast('订单已取消，库存已恢复')
  } catch (e: any) {
    showToast(e.message || '取消失败')
  }
}

function handlePaid() {
  showToast('支付成功！')
  orderStore.fetchOrders()
}
</script>

<template>
  <div>
    <div class="page-header"><h2>我的订单</h2></div>

    <div v-if="orderStore.loading" class="spin"></div>

    <div v-if="!orderStore.loading && orderStore.orders.length === 0" class="empty">
      <div class="empty-icon">📋</div>
      <p>暂无订单</p>
    </div>

    <OrderCard
      v-for="o in orderStore.orders" :key="o.id"
      :order="o"
      @detail="goDetail"
      @pay="openPay"
      @cancel="handleCancel"
    />

    <!-- 支付弹窗 -->
    <PaymentModal
      v-if="paying && payingOrder"
      :order="payingOrder"
      @close="paying = false"
      @paid="handlePaid"
    />
  </div>
</template>

<style scoped>
.page-header { padding: 24px 0 0; margin-bottom: 16px; }
.page-header h2 { font-size: 24px; font-weight: 800; }
.spin {
  width: 36px; height: 36px;
  border: 3px solid var(--border);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin .8s linear infinite;
  margin: 40px auto;
}
@keyframes spin { to { transform: rotate(360deg) } }
.empty { padding: 60px 20px; text-align: center; color: var(--ink3); }
.empty-icon { font-size: 48px; margin-bottom: 12px; }
</style>
