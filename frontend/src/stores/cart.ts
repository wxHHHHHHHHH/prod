import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export interface CartItem {
  id: number; name: string; price: number; imageUrl: string
  quantity: number; stock: number
}

/**
 * 购物车 Store — localStorage 持久化
 *
 * 学习重点:
 * 1. Pinia 组合式 API 写法（ref + computed）
 * 2. 本地持久化: 通过 watch 或手动调用 saveToLocalStorage
 * 3. 计算属性: cartTotal 自动计算总价
 */
export const useCartStore = defineStore('cart', () => {
  // 从 localStorage 恢复
  const saved = localStorage.getItem('mall_cart')
  const items = ref<CartItem[]>(saved ? JSON.parse(saved) : [])

  const cartTotal = computed(() =>
    items.value.reduce((sum, i) => sum + i.price * i.quantity, 0)
  )

  const cartCount = computed(() =>
    items.value.reduce((sum, i) => sum + i.quantity, 0)
  )

  function saveToLocalStorage() {
    localStorage.setItem('mall_cart', JSON.stringify(items.value))
  }

  function addItem(product: { id: number; name: string; price: number; imageUrl?: string; stock: number }, quantity: number) {
    const existing = items.value.find(i => i.id === product.id)
    if (existing) {
      existing.quantity = Math.min(existing.quantity + quantity, existing.stock)
    } else {
      items.value.push({
        id: product.id,
        name: product.name,
        price: product.price,
        imageUrl: product.imageUrl || '',
        quantity: Math.min(quantity, product.stock),
        stock: product.stock
      })
    }
    saveToLocalStorage()
  }

  function removeItem(id: number) {
    items.value = items.value.filter(i => i.id !== id)
    saveToLocalStorage()
  }

  function updateQuantity(id: number, quantity: number) {
    const item = items.value.find(i => i.id === id)
    if (item && quantity > 0 && quantity <= item.stock) {
      item.quantity = quantity
      saveToLocalStorage()
    }
  }

  function clearCart() {
    items.value = []
    localStorage.removeItem('mall_cart')
  }

  return { items, cartTotal, cartCount, addItem, removeItem, updateQuantity, clearCart }
})
