interface ShopItem {
  name: string
  label: string
  category: string
  price: number
  license?: {
    required: boolean
    mode: "framework" | "inventory"
    type: string
  }
}

interface CartItem extends ShopItem {
  quantity: number
}
