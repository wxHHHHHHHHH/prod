import { defineStore } from 'pinia'
import { ref } from 'vue'
import { listOrders, getOrderDetail, cancelOrder as cancelOrderApi } from '@/api/order'

export interface OrderItem {
  id: number; orderNo: string; userId: number
  productId: number; productName: string
  quantity: number; unitPrice: number; totalAmount: number
  status: string; payTime: string; createTime: string
}

export const useOrderStore = defineStore('order', () => {
  const orders = ref<OrderItem[]>([])
  const loading = ref(false)

  async function fetchOrders(page = 1, size = 50) {
    loading.value = true
    try {
      const res = await listOrders(page, size)
      orders.value = res.data?.records || []
    } finally {
      loading.value = false
    }
  }

  async function cancelOrder(id: number) {
    await cancelOrderApi(id)
    // 本地更新状态
    const order = orders.value.find(o => o.id === id)
    if (order) order.status = 'CANCELLED'
  }

  return { orders, loading, fetchOrders, cancelOrder }
})
