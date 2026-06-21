import request from './request'

export interface AddressItem {
  id?: number; receiverName: string; receiverPhone: string
  province: string; city: string; district: string; detail: string
  isDefault: number
}

export function listAddresses() {
  return request.get('/address/list')
}
export function createAddress(data: AddressItem) {
  return request.post('/address', data)
}
export function updateAddress(id: number, data: AddressItem) {
  return request.put(`/address/${id}`, data)
}
export function deleteAddress(id: number) {
  return request.delete(`/address/${id}`)
}
