import { defineStore } from 'pinia'
import { ref } from 'vue'
export const useManagerStore = defineStore('manager', () => {
  const showManager = ref(false)
  return { showManager }
})
