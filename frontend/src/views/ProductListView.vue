<script setup lang="ts">
import { ref, inject, onMounted } from 'vue'
import { listProducts, type ProductItem } from '@/api/product'
import { useCartStore } from '@/stores/cart'
import ProductCard from '@/components/ProductCard.vue'

const showToast = inject<(msg: string, duration?: number) => void>('showToast')!
const cart = useCartStore()

const products = ref<ProductItem[]>([])
const loading = ref(true)
const selected = ref<ProductItem | null>(null)
const buyQty = ref(1)

onMounted(async () => {
  try {
    const res = await listProducts()
    products.value = res.data?.records || []
  } catch (e: any) {
    showToast('加载商品失败: ' + (e.message || '网络错误'))
  } finally {
    loading.value = false
  }
})

function openProduct(p: ProductItem) {
  selected.value = p
  buyQty.value = 1
}

function addToCart() {
  if (selected.value) {
    cart.addItem(selected.value, buyQty.value)
    showToast(`已添加 ${buyQty.value} 件到购物车`)
    selected.value = null
  }
}
</script>

<template>
  <div>
    <!-- 分类筛选 -->
    <div class="page-header">
      <h2>全部商品</h2>
      <div class="categories">
        <button class="cat-btn active">全部</button>
        <button class="cat-btn">电子书</button>
        <button class="cat-btn">数码</button>
        <button class="cat-btn">家具</button>
      </div>
    </div>

    <!-- 加载中 -->
    <div v-if="loading" class="spin"></div>

    <!-- 商品列表 -->
    <div class="product-grid" v-if="!loading">
      <ProductCard
        v-for="p in products" :key="p.id"
        :product="p"
        @click="openProduct"
      />
    </div>
    <div class="empty" v-if="!loading && products.length === 0">
      <div class="empty-icon">📦</div>
      <p>暂无商品</p>
    </div>

    <!-- 商品详情弹窗 -->
    <div class="modal-overlay" v-if="selected" @click.self="selected = null">
      <div class="modal">
        <div class="modal-header">
          <h2>{{ selected.name }}</h2>
          <button class="modal-close" @click="selected = null">✕</button>
        </div>
        <div class="modal-body">
          <div class="detail-img">{{ selected.name?.charAt(0) || '📦' }}</div>
          <p class="detail-desc">{{ selected.description }}</p>
          <div class="detail-row">
            <span class="product-price" style="font-size:28px">¥{{ selected.price }}</span>
            <span style="color:var(--ink3);font-size:14px">库存: {{ selected.stock }}</span>
          </div>
          <div class="detail-row qty-row">
            <label>数量:</label>
            <input
              class="input" type="number"
              v-model.number="buyQty" min="1" :max="selected.stock"
              style="width:80px;text-align:center"
            >
            <button class="btn btn-primary" style="width:auto;flex:1" @click="addToCart">
              加入购物车
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page-header {
  padding: 24px 0 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
}
.page-header h2 { font-size: 24px; font-weight: 800; }
.categories { display: flex; gap: 4px; }
.cat-btn {
  padding: 8px 16px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border);
  cursor: pointer;
  font-size: 13px;
  font-family: inherit;
  background: var(--surface);
  color: var(--ink2);
  transition: all .15s;
}
.cat-btn.active, .cat-btn:hover { background: var(--accent); color: #fff; border-color: var(--accent); }
.product-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 20px;
  padding: 24px 0;
}
@media (max-width: 640px) {
  .product-grid { grid-template-columns: repeat(2, 1fr); gap: 12px; }
}
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
.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.4);
  z-index: 200; display: flex; align-items: center; justify-content: center;
  animation: fadeIn .2s;
}
@keyframes fadeIn { from { opacity: 0 } }
.modal {
  background: var(--surface); border-radius: var(--radius);
  width: 90%; max-width: 500px; max-height: 85vh; overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,.1);
  animation: slideUp .25s cubic-bezier(0,0,.2,1);
}
@keyframes slideUp { from { opacity: 0; transform: translateY(20px) } }
.modal-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 20px 24px; border-bottom: 1px solid var(--border);
}
.modal-header h2 { font-size: 18px; font-weight: 700; }
.modal-close {
  background: none; border: none; font-size: 22px; cursor: pointer;
  color: var(--ink3); width: 36px; height: 36px; border-radius: 50%;
}
.modal-close:hover { background: var(--bg); color: var(--ink); }
.modal-body { padding: 24px; }
.detail-img {
  height: 200px; border-radius: var(--radius); margin-bottom: 16px;
  background: linear-gradient(135deg, #f0f0ff, #fff0f0);
  display: flex; align-items: center; justify-content: center;
  font-size: 64px;
}
.detail-desc { color: var(--ink3); margin-bottom: 16px; line-height: 1.6; }
.detail-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; gap: 12px; }
.qty-row { justify-content: flex-start; }
.qty-row label { font-weight: 600; font-size: 14px; }
.product-price { font-size: 22px; font-weight: 800; color: var(--warm); }
.product-price::before { content: '¥'; font-size: 14px; }
.input {
  padding: 10px 14px; border: 1px solid var(--border);
  border-radius: var(--radius-sm); font-size: 15px; font-family: inherit;
  background: var(--bg); transition: all .15s;
}
.input:focus { outline: none; border-color: var(--accent); }
.btn {
  padding: 13px; border: none; border-radius: var(--radius-sm);
  cursor: pointer; font-size: 15px; font-weight: 600; font-family: inherit;
  transition: all .15s;
}
.btn-primary { background: var(--accent); color: #fff; }
.btn-primary:hover { background: var(--accent2); }
</style>
