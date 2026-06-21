import request from './request'

export interface ProductItem {
  id: number; name: string; description: string
  price: number; stock: number; imageUrl: string; category: string
  status: number; createTime: string
}
export interface ProductPage { records: ProductItem[]; total: number; size: number; current: number }

export function listProducts(page = 1, size = 10, category?: string) {
  return request.get('/product/list', { params: { page, size, category } })
}
export function getProductDetail(id: number) {
  return request.get(`/product/detail/${id}`)
}
