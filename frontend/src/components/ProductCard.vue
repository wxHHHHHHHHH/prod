<script setup lang="ts">
import type { ProductItem } from '@/api/product'

defineProps<{ product: ProductItem }>()
const emit = defineEmits<{ (e: 'click', product: ProductItem): void }>()
</script>

<template>
  <div class="product-card" @click="emit('click', product)">
    <div class="product-img">
      <span class="emoji">{{ product.name?.charAt(0) || '📦' }}</span>
    </div>
    <div class="product-body">
      <div class="product-name">{{ product.name }}</div>
      <div class="product-desc">{{ product.description }}</div>
      <div class="product-footer">
        <span class="product-price">{{ product.price }}</span>
        <span class="product-stock">库存 {{ product.stock }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.product-card {
  background: var(--surface);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  overflow: hidden;
  cursor: pointer;
  transition: all .2s;
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0,0,0,.08);
}
.product-img {
  width: 100%;
  aspect-ratio: 4/3;
  background: linear-gradient(135deg, #f0f0ff, #fff0f0);
  display: flex;
  align-items: center;
  justify-content: center;
}
.emoji { font-size: 48px; }
.product-body { padding: 16px; }
.product-name { font-weight: 600; font-size: 16px; margin-bottom: 4px; }
.product-desc {
  font-size: 13px;
  color: var(--ink3);
  margin-bottom: 8px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.product-footer { display: flex; justify-content: space-between; align-items: center; }
.product-price { font-size: 22px; font-weight: 800; color: var(--warm); }
.product-price::before { content: '¥'; font-size: 14px; }
.product-stock { font-size: 12px; color: var(--ink3); }
</style>
