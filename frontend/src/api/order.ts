import request from './request'

export function createOrder(productId: number, quantity: number, addressId?: number) {
  return request.post('/order/create', { productId, quantity, addressId })
}
export function listOrders(page = 1, size = 10) {
  return request.get('/order/list', { params: { page, size } })
}
export function getOrderDetail(id: number) {
  return request.get(`/order/detail/${id}`)
}
export function cancelOrder(id: number) {
  return request.put(`/order/cancel/${id}`)
}
