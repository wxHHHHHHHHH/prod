<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { listAddresses, type AddressItem } from '@/api/address'

const emit = defineEmits<{ (e: 'select', address: AddressItem): void }>()
const addresses = ref<AddressItem[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    const res = await listAddresses()
    addresses.value = res.data || []
  } catch (e) {
    console.error('加载地址失败', e)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div>
    <p class="label" v-if="!loading">选择收货地址</p>
    <p v-if="loading" style="color:var(--ink3);padding:12px 0">加载地址中...</p>
    <p v-if="!loading && addresses.length === 0" style="color:var(--ink3);padding:12px 0">
      ⚠️ 暂无收货地址，请先添加地址
    </p>
    <div
      v-for="addr in addresses"
      :key="addr.id"
      class="addr-card"
      @click="emit('select', addr)"
    >
      <div style="font-weight:600">
        {{ addr.receiverName }} {{ addr.receiverPhone }}
        <span v-if="addr.isDefault" class="default-tag">默认</span>
      </div>
      <div style="font-size:13px;color:var(--ink2);margin-top:4px">
        {{ addr.province }}{{ addr.city }}{{ addr.district }} {{ addr.detail }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.label { font-weight: 600; font-size: 14px; margin-bottom: 8px; color: var(--ink2); }
.addr-card {
  padding: 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  margin-bottom: 8px;
  cursor: pointer;
  transition: all .15s;
}
.addr-card:hover { border-color: var(--accent); background: #f8f9ff; }
.default-tag {
  font-size: 11px;
  background: var(--accent);
  color: #fff;
  padding: 1px 6px;
  border-radius: 8px;
  margin-left: 6px;
}
</style>
