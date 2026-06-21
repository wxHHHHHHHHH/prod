<script setup lang="ts">
import { ref } from 'vue'
import { createPayment } from '@/api/payment'

const props = defineProps<{ order: { id: number; totalAmount: number; orderNo?: string } }>()
const emit = defineEmits<{
  (e: 'close'): void
  (e: 'paid'): void
}>()

const step = ref<'choose' | 'qrcode' | 'done'>('choose')
const payInfo = ref<any>(null)
const loading = ref(false)

async function doPay(payType: string) {
  loading.value = true
  try {
    const res = await createPayment(props.order.id, props.order.totalAmount, payType)
    payInfo.value = res.data
    step.value = 'qrcode'
  } catch (e: any) {
    alert(e.message || '创建支付失败')
  } finally {
    loading.value = false
  }
}

function simulatePaySuccess() {
  step.value = 'done'
  // 实际场景: 轮询支付状态或 WebSocket 通知
  setTimeout(() => emit('paid'), 1500)
}
</script>

<template>
  <div class="modal-overlay" @click.self="emit('close')">
    <div class="modal">
      <div class="modal-header">
        <h2>💳 收银台</h2>
        <button class="modal-close" @click="emit('close')">✕</button>
      </div>
      <div class="modal-body">
        <div class="pay-emoji">
          {{ step === 'choose' ? '💳' : (step === 'qrcode' ? '📱' : '✅') }}
        </div>

        <!-- 选择支付方式 -->
        <div v-if="step === 'choose'">
          <p class="pay-amount">¥{{ order.totalAmount }}</p>
          <p class="pay-sub">订单号: {{ order.orderNo }}</p>
          <div class="pay-buttons">
            <button class="btn btn-primary" @click="doPay('ALIPAY')" :disabled="loading">
              {{ loading ? '...' : '支付宝 支付' }}
            </button>
            <button class="btn" style="background:#07c160;color:#fff" @click="doPay('WECHAT')" :disabled="loading">
              {{ loading ? '...' : '微信 支付' }}
            </button>
          </div>
        </div>

        <!-- 扫码支付(模拟) -->
        <div v-if="step === 'qrcode'">
          <p class="pay-label">请扫码支付</p>
          <p class="pay-amount" style="font-size:28px">¥{{ order.totalAmount }}</p>
          <div class="qrcode-box">{{ payInfo?.payNo || '生成中...' }}</div>
          <button class="btn btn-primary" style="margin-top:16px" @click="simulatePaySuccess()">
            模拟支付成功
          </button>
          <button class="btn btn-outline" style="margin-top:8px" @click="step = 'choose'">
            返回选择
          </button>
        </div>

        <!-- 支付成功 -->
        <div v-if="step === 'done'">
          <p class="success-text">支付成功！🎉</p>
          <button class="btn btn-primary" style="width:auto;margin-top:12px" @click="emit('paid');emit('close')">
            查看订单
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.4);
  z-index: 200;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn .2s;
}
@keyframes fadeIn { from { opacity: 0 } }
.modal {
  background: var(--surface);
  border-radius: var(--radius);
  width: 90%;
  max-width: 420px;
  max-height: 85vh;
  overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,.1);
  animation: slideUp .25s cubic-bezier(0,0,.2,1);
}
@keyframes slideUp { from { opacity: 0; transform: translateY(20px) } }
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  border-bottom: 1px solid var(--border);
}
.modal-header h2 { font-size: 18px; font-weight: 700; }
.modal-close {
  background: none;
  border: none;
  font-size: 22px;
  cursor: pointer;
  color: var(--ink3);
  width: 36px;
  height: 36px;
  border-radius: 50%;
}
.modal-close:hover { background: var(--bg); color: var(--ink); }
.modal-body { padding: 24px; text-align: center; }
.pay-emoji { font-size: 64px; margin-bottom: 12px; }
.pay-amount { font-weight: 600; font-size: 18px; margin-bottom: 4px; }
.pay-sub { color: var(--ink3); margin-bottom: 20px; font-size: 14px; }
.pay-label { font-weight: 600; margin-bottom: 4px; }
.pay-buttons { display: flex; flex-direction: column; gap: 10px; }
.qrcode-box {
  background: var(--bg);
  padding: 20px;
  border-radius: var(--radius);
  font-family: monospace;
  font-size: 11px;
  word-break: break-all;
  color: var(--ink3);
  margin: 16px 0;
}
.success-text { font-size: 24px; font-weight: 800; color: #065f46; margin-bottom: 8px; }
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
.btn-primary { background: var(--accent); color: #fff; }
.btn-primary:hover { background: var(--accent2); }
.btn-outline { background: transparent; border: 1px solid var(--border); color: var(--ink2); }
.btn-outline:hover { border-color: var(--ink2); }
.btn:disabled { opacity: .5; cursor: not-allowed; }
</style>
