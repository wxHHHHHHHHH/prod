<script setup lang="ts">
defineProps<{ message: string; visible: boolean }>()
</script>

<template>
  <Transition name="toast">
    <div class="toast" v-if="visible">{{ message }}</div>
  </Transition>
</template>

<style scoped>
.toast {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--ink);
  color: #fff;
  padding: 12px 24px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  z-index: 999;
}
.toast-enter-active { animation: toastIn .3s ease; }
.toast-leave-active { animation: toastIn .3s ease reverse; }
@keyframes toastIn {
  from { opacity: 0; transform: translateX(-50%) translateY(10px); }
}
</style>
