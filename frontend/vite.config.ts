import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: { '@': resolve(__dirname, 'src') }
  },
  server: {
    port: 3000,
    proxy: {
      '/api': {
        // 本地后端: http://localhost:8080
        // 远程后端: http://47.108.130.167:8080
        target: 'http://47.108.130.167:8080',
        changeOrigin: true
      }
    }
  }
})
