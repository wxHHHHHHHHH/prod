import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      redirect: '/products'
    },
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/LoginView.vue'),
      meta: { noAuth: true }
    },
    {
      path: '/products',
      name: 'Products',
      component: () => import('@/views/ProductListView.vue')
    },
    {
      path: '/cart',
      name: 'Cart',
      component: () => import('@/views/CartView.vue')
    },
    {
      path: '/orders',
      name: 'Orders',
      component: () => import('@/views/OrderListView.vue')
    },
    {
      path: '/orders/:id',
      name: 'OrderDetail',
      component: () => import('@/views/OrderDetailView.vue')
    }
  ]
})

// 路由守卫 — 无 token 跳转登录页
router.beforeEach((to, _from, next) => {
  const token = localStorage.getItem('mall_token')
  if (!to.meta.noAuth && !token) {
    next('/login')
  } else {
    next()
  }
})

export default router
