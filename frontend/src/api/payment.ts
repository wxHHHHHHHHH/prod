import request from './request'

export function createPayment(orderId: number, amount: number, payType: string) {
  return request.post('/payment/create', { orderId, amount, payType })
}
export function queryPayment(payNo: string) {
  return request.get('/payment/query', { params: { payNo } })
}
export function refundPayment(payNo: string, reason: string) {
  return request.post('/payment/refund', { payNo, reason })
}
