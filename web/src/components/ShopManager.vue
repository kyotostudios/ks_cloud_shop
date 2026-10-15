<script setup lang="ts">
import { computed, onMounted, ref } from "vue"
import { Icon } from "@iconify/vue"
import { callback } from "@/utils/callback"
import { formatPrice } from "@/utils/formatPrice"
import { categoryIcons, resolveCategoryIcon } from "@/utils/categoryIcons"
import { useManagerStore } from "@/stores/manager"
const manager = useManagerStore()
const shops = ref<Record<string, any>>({})
const template = ref<any>(null)
const selected = ref("")
const draft = ref<any>(null)
const newKey = ref("")
const tab = ref<"general" | "positions" | "categories" | "items" | "access">("general")
const search = ref("")
const status = ref("")
const busy = ref(false)
const deleteConfirm = ref(false)
const licenseTarget = ref("")
const licenseType = ref("")
// Catálogo de produtos vem exclusivamente do servidor (ox_inventory).
const imagePath = ref("nui://ox_inventory/web/images/")
const catalog = ref<Array<{ name: string; label: string }>>([])
const inventoryAvailable = ref(false)
const catalogLoaded = ref(false)
const catalogLoading = ref(false)
const catalogError = ref("")
const catalogQuery = ref("")
const catalogLimit = ref(100)
const browseModal = ref(false)
const itemModal = ref(false)
const deleteItemModal = ref(false)
const editedIndex = ref<number | null>(null)
const deletingIndex = ref<number | null>(null)
const itemDraft = ref<any>(null)
const itemError = ref("")
const clone = (value: any) => JSON.parse(JSON.stringify(value))
const itemImage = (name: string) => `${imagePath.value}${encodeURIComponent(name)}.png`
const fallbackImage = "item_images/fallback-item.webp"
const onImageError = (event: Event) => {
  const img = event.target as HTMLImageElement
  if (!img || img.dataset.fallback === "1") return
  img.dataset.fallback = "1"
  img.src = fallbackImage
}
const catalogFiltered = computed(() => {
  const query = catalogQuery.value.trim().toLowerCase()
  return !query ? catalog.value : catalog.value.filter(item => item.name.toLowerCase().includes(query) || item.label.toLowerCase().includes(query))
})
const catalogVisible = computed(() => catalogFiltered.value.slice(0, catalogLimit.value))
const closeProductDialogs = () => {
  itemModal.value = false
  deleteItemModal.value = false
  browseModal.value = false
  editedIndex.value = null
  deletingIndex.value = null
  itemError.value = ""
}
const openNewProduct = () => {
  if (!draft.value) return
  closeProductDialogs()
  const category = draft.value.Categories.find((cat: any) => cat.type !== "all")?.type || "all"
  itemDraft.value = { name: "", label: "", category, price: 0, license: { required: false, mode: "framework", type: "weapon" } }
  itemModal.value = true
}
const editProduct = (item: any) => {
  if (!draft.value) return
  closeProductDialogs()
  editedIndex.value = draft.value.Items.indexOf(item)
  if (editedIndex.value === null || editedIndex.value < 0) return
  itemDraft.value = clone(item)
  itemDraft.value.license ??= { required: false, mode: "framework", type: "weapon" }
  itemModal.value = true
}
const saveProduct = () => {
  if (!draft.value || !itemDraft.value) return
  const item = clone(itemDraft.value)
  item.name = String(item.name || "").trim()
  item.label = String(item.label || "").trim()
  item.price = Number(item.price)
  if (!/^[a-zA-Z0-9_-]{1,64}$/.test(item.name)) {
    itemError.value = "Identificador inválido (1 a 64 letras, números, _ ou -)."
    return
  }
  if (!item.label || item.label.length > 100) {
    itemError.value = "Informe um nome de até 100 caracteres."
    return
  }
  if (!Number.isSafeInteger(item.price) || item.price < 0 || item.price > 100000000) {
    itemError.value = "Informe um preço inteiro entre 0 e 100.000.000."
    return
  }
  if (!draft.value.Categories.some((cat: any) => cat.type === item.category)) {
    itemError.value = "Selecione uma categoria válida."
    return
  }
  const duplicate = draft.value.Items.some((current: any, index: number) => index !== editedIndex.value && current.name === item.name)
  if (duplicate) {
    itemError.value = "Este item já está cadastrado nesta loja."
    return
  }
  if (item.license?.required && !/^[a-zA-Z0-9_-]{1,64}$/.test(item.license.type || "")) {
    itemError.value = "Tipo de licença inválido."
    return
  }
  if (!item.license?.required) item.license = { required: false, mode: "framework", type: "weapon" }
  if (editedIndex.value === null) draft.value.Items.push(item)
  else draft.value.Items.splice(editedIndex.value, 1, item)
  closeProductDialogs()
  status.value = "Produto alterado no rascunho. Clique em Salvar alterações para publicar."
}
const askDeleteProduct = (item: any) => {
  if (!draft.value) return
  deletingIndex.value = draft.value.Items.indexOf(item)
  deleteItemModal.value = deletingIndex.value !== null && deletingIndex.value >= 0
}
const confirmDeleteProduct = () => {
  if (deletingIndex.value === null || !draft.value) return
  draft.value.Items.splice(deletingIndex.value, 1)
  closeProductDialogs()
  status.value = "Produto removido do rascunho. Clique em Salvar alterações para publicar."
}
const loadCatalog = async () => {
  if (catalogLoaded.value || catalogLoading.value) return
  catalogLoading.value = true
  catalogError.value = ""
  try {
    const result = await callback({ action: "manager:inventoryItems" })
    if (!result?.success || !Array.isArray(result.items)) {
      catalogError.value = result?.reason || "Não foi possível consultar o ox_inventory."
      inventoryAvailable.value = false
      return
    }
    catalog.value = result.items
    inventoryAvailable.value = true
    catalogLoaded.value = true
  } catch {
    catalogError.value = "Falha de comunicação com o servidor."
  } finally {
    catalogLoading.value = false
  }
}
const openCatalog = async () => {
  catalogQuery.value = ""
  catalogLimit.value = 100
  browseModal.value = true
  await loadCatalog()
}
const selectCatalogItem = (item: { name: string; label: string }) => {
  if (!itemDraft.value) return
  itemDraft.value.name = item.name
  itemDraft.value.label = item.label
  browseModal.value = false
  itemError.value = ""
}
const keys = computed(() => Object.keys(shops.value).sort())
const tabs = [
  ["general", "Geral"],
  ["positions", "Localizações"],
  ["categories", "Categorias"],
  ["items", "Produtos"],
  ["access", "Licenças e acesso"],
] as const
const completeDraft = (value: any) => {
  for (const item of value.Items ?? []) item.license ??= { required: false, mode: "framework", type: "weapon" }
  value.Requirement.License.mode ??= "framework"
  return value
}
const displayedItems = computed(() => (draft.value?.Items ?? []).filter((p: any) => `${p.name} ${p.label}`.toLowerCase().includes(search.value.toLowerCase())))
const close = async () => {
  await callback({ action: "manager:close" })
  manager.showManager = false
}
const load = async () => {
  const result = await callback({ action: "manager:data" })
  if (!result?.shops) {
    status.value = "Não foi possível carregar as lojas."
    return
  }
  shops.value = result.shops
  template.value = result.template
  if (typeof result.imagePath === "string" && result.imagePath) imagePath.value = result.imagePath
  if (selected.value && shops.value[selected.value]) select(selected.value)
  else if (!draft.value && keys.value.length) select(keys.value[0])
}
const select = (key: string) => {
  closeProductDialogs()
  selected.value = key
  draft.value = completeDraft(clone(shops.value[key]))
  deleteConfirm.value = false
  status.value = ""
  tab.value = "general"
}
const create = () => {
  const key = newKey.value.trim().toLowerCase()
  if (!/^[a-z0-9_-]{1,64}$/.test(key)) {
    status.value = "ID inválido. Use letras, números, _ ou -."
    return
  }
  if (shops.value[key]) {
    status.value = "Essa loja já existe."
    return
  }
  selected.value = key
  draft.value = completeDraft(clone(template.value))
  draft.value.Locales.MainHeader.title = key.replace(/_/g, " ")
  draft.value.Locations = []
  status.value = "Nova loja: configure uma localização e clique em salvar."
  tab.value = "general"
  newKey.value = ""
}
const save = async () => {
  if (!draft.value || busy.value) return
  busy.value = true
  try {
    const result = await callback({ action: "manager:save", key: selected.value, shop: draft.value })
    status.value = result?.success ? "Loja salva e sincronizada." : result?.reason || "Erro ao salvar a loja."
    if (result?.success) {
      const message = status.value
      const keepTab = tab.value
      await load()
      tab.value = keepTab
      status.value = message
    }
  } finally {
    busy.value = false
  }
}
const remove = async () => {
  if (!deleteConfirm.value || busy.value) return
  busy.value = true
  try {
    const result = await callback({ action: "manager:delete", key: selected.value })
    status.value = result?.success ? "Loja excluída." : result?.reason || "Erro ao excluir."
    if (result?.success) {
      selected.value = ""
      draft.value = null
      await load()
    }
  } finally {
    busy.value = false
    deleteConfirm.value = false
  }
}
const addPosition = async () => {
  const pos = await callback({ action: "manager:position" })
  if (pos?.x !== undefined) draft.value.Locations.push(pos)
}
const addCategory = () => {
  const id = `category_${Date.now().toString(36)}`
  draft.value.Categories.push({ type: id, name: "Nova categoria", icon: categoryIcons[0]?.id || "ic:round-clear-all" })
}
const removeCategory = (index: number) => {
  const category = draft.value.Categories[index]
  if (category.type === "all" || draft.value.Items.some((i: any) => i.category === category.type)) {
    status.value = "Remova ou mova os produtos dessa categoria primeiro."
    return
  }
  draft.value.Categories.splice(index, 1)
}
const issueLicense = async () => {
  const result = await callback({ action: "manager:grantLicense", target: Number(licenseTarget.value), licenseType: licenseType.value })
  status.value = result?.reason || "Falha ao emitir licença."
}
onMounted(load)
</script>

<template>
  <main class="manager-container">
    <div class="manager-layout">
      <header class="manager-header">
        <div>
          <div class="heading">
            <h1>SHOP MANAGER</h1>
            <span>ADMIN</span>
          </div>
          <p>Gerenciamento de lojas, produtos e licenças</p>
        </div>
        <button class="close" @click="close" aria-label="Fechar">×</button>
      </header>
      <div class="manager-content">
        <aside class="sidebar">
          <h2>LOJAS</h2>
          <button v-for="key in keys" :key="key" class="store-choice" :class="{ active: selected === key }" @click="select(key)">
            <strong>{{ shops[key]?.Locales?.MainHeader?.title || key }}</strong
            ><small>{{ key }}</small>
          </button>
          <div class="create-row"><input v-model="newKey" placeholder="id_da_nova_loja" maxlength="64" @keyup.enter="create" /><button @click="create">+</button></div>
          <p class="muted">O identificador não poderá ser alterado depois de criado.</p>
        </aside>
        <section class="editor" v-if="draft">
          <div class="editor-header">
            <div>
              <h2>{{ draft.Locales.MainHeader.title }}</h2>
              <p>{{ selected }}</p>
            </div>
            <button class="save-button" :disabled="busy" @click="save">SALVAR ALTERAÇÕES</button>
          </div>
          <nav class="tabs">
            <button v-for="section in tabs" :key="section[0]" :class="{ active: tab === section[0] }" @click="tab = section[0]">{{ section[1] }}</button>
          </nav>
          <div class="scroll-panel" v-if="tab === 'general'">
            <section class="settings-section">
              <div class="section-heading">
                <h3>Informações da loja</h3>
                <p>Títulos e textos exibidos para o jogador.</p>
              </div>
              <div class="form-grid">
                <label>Título da loja<input v-model="draft.Locales.MainHeader.title" maxlength="500" /></label>
                <label>Etiqueta do título<input v-model="draft.Locales.MainHeader.tag" maxlength="500" /></label>
                <label class="wide">Descrição da loja<textarea v-model="draft.Locales.MainHeader.description" rows="3" maxlength="500" /></label>
                <label>Título do carrinho<input v-model="draft.Locales.CartHeader.title" maxlength="500" /></label>
                <label>Etiqueta do carrinho<input v-model="draft.Locales.CartHeader.tag" maxlength="500" /></label>
                <label class="wide">Descrição do carrinho<textarea v-model="draft.Locales.CartHeader.description" rows="2" maxlength="500" /></label>
              </div>
            </section>
            <section class="settings-section">
              <div class="section-heading">
                <h3>Mapa e proximidade</h3>
                <p>Configurações do blip e distância de ativação.</p>
              </div>
              <div class="form-grid">
                <label>Nome do blip<input v-model="draft.Blip.name" maxlength="90" /></label>
                <label>Raio de streaming<input type="number" v-model.number="draft.PointRadius" min="2" max="250" /></label>
                <label>Sprite do blip<input type="number" v-model.number="draft.Blip.sprite" min="0" max="1000" /></label>
                <label>Cor do blip<input type="number" v-model.number="draft.Blip.color" min="0" max="100" /></label>
                <label>Escala do blip<input type="number" v-model.number="draft.Blip.scale" min="0.1" max="2" step="0.1" /></label>
              </div>
            </section>
            <section class="settings-section">
              <div class="section-heading">
                <h3>Atendente</h3>
                <p>NPC, cenário e opções de interação.</p>
              </div>
              <div class="form-grid">
                <label>Modelo do ped (nome ou hash)<input v-model="draft.Indicator.Ped.model" /></label>
                <label>Cenário do ped<input v-model="draft.Indicator.Ped.scenario" /></label>
              </div>
              <div class="switch-grid">
                <label class="toggle-option"><input type="checkbox" v-model="draft.Blip.enabled" /><span>Exibir blip</span></label>
                <label class="toggle-option"><input type="checkbox" v-model="draft.Indicator.Ped.enabled" /><span>Exibir ped</span></label>
                <label class="toggle-option"><input type="checkbox" v-model="draft.Indicator.Marker.enabled" /><span>Exibir marcador</span></label>
                <label class="toggle-option"><input type="checkbox" v-model="draft.Interaction.HelpText.enabled" /><span>Texto de ajuda</span></label>
                <label class="toggle-option"><input type="checkbox" v-model="draft.Interaction.FloatingText.enabled" /><span>Texto flutuante</span></label>
                <label class="toggle-option"><input type="checkbox" v-model="draft.Interaction.Target.enabled" /><span>ox_target</span></label>
              </div>
            </section>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'positions'">
            <div class="row-line">
              <h3>Localizações da loja</h3>
              <button @click="addPosition">+ USAR POSIÇÃO ATUAL</button>
            </div>
            <div class="data-card" v-for="(pos, index) in draft.Locations" :key="index">
              <div class="row-line">
                <strong>PONTO {{ index + 1 }}</strong
                ><button class="danger-text" @click="draft.Locations.splice(index, 1)">REMOVER</button>
              </div>
              <div class="coordinate-grid">
                <label>X<input type="number" v-model.number="pos.x" step="0.0001" /></label><label>Y<input type="number" v-model.number="pos.y" step="0.0001" /></label
                ><label>Z<input type="number" v-model.number="pos.z" step="0.0001" /></label><label>Heading<input type="number" v-model.number="pos.w" step="0.01" /></label>
              </div>
            </div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'categories'">
            <div class="row-line">
              <h3>Categorias</h3>
              <button @click="addCategory">+ CATEGORIA</button>
            </div>
            <div class="data-card" v-for="(cat, index) in draft.Categories" :key="index">
              <div class="category-edit">
                <div class="icon-preview"><img v-if="resolveCategoryIcon(cat.icon)" :src="resolveCategoryIcon(cat.icon)" alt="Ícone" /></div>
                <label>Identificador<input v-model="cat.type" :disabled="cat.type === 'all'" /></label><label>Nome<input v-model="cat.name" /></label
                ><label
                  >Ícone<select v-model="cat.icon">
                    <option v-if="!categoryIcons.some(i => i.id === cat.icon)" :value="cat.icon">{{ cat.icon }} (legado)</option>
                    <option v-for="icon in categoryIcons" :value="icon.id" :key="icon.id">{{ icon.id.replace("local:", "") }}</option>
                  </select></label
                ><button class="danger-text" :disabled="cat.type === 'all'" @click="removeCategory(index)">EXCLUIR</button>
              </div>
            </div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'items'">
            <div class="row-line">
              <div>
                <h3>Produtos</h3>
                <p class="muted">Clique em um card para configurar o produto.</p>
              </div>
              <button @click="openNewProduct">+ PRODUTO</button>
            </div>
            <input class="search" v-model="search" placeholder="Pesquisar produto pelo nome ou identificador..." />
            <div v-if="!displayedItems.length" class="empty-products">Nenhum produto encontrado.</div>
            <div v-else class="product-grid">
              <div
                v-for="item in displayedItems"
                :key="item.name"
                class="product-card"
                role="button"
                tabindex="0"
                :aria-label="`Editar ${item.label}`"
                @click="editProduct(item)"
                @keydown.enter.prevent="editProduct(item)"
                @keydown.space.prevent="editProduct(item)"
              >
                <div class="product-card-top">
                  <span class="price-tag">{{ formatPrice(Number(item.price)) }}</span
                  ><button class="product-delete" :aria-label="`Excluir ${item.label}`" title="Excluir produto" @click.stop="askDeleteProduct(item)">
                    <Icon icon="mdi:trash-can-outline" />
                  </button>
                </div>
                <div class="product-image"><img :key="item.name" :src="itemImage(item.name)" :alt="item.label" @error="onImageError" draggable="false" /></div>
                <div class="product-name" :title="item.label">{{ item.label }}</div>
                <div class="product-id" :title="item.name">{{ item.name }}</div>
              </div>
            </div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'access'">
            <section class="settings-section">
              <div class="row-line">
                <div class="section-heading">
                  <h3>Requisitos de emprego</h3>
                  <p>Controle quais empregos podem acessar a loja.</p>
                </div>
                <button v-if="draft.Requirement.Job.required" @click="draft.Requirement.Job.jobs.push({ name: 'police', label: 'Polícia', grade: 0 })">+ EMPREGO</button>
              </div>
              <label class="toggle-option"><input type="checkbox" v-model="draft.Requirement.Job.required" /><span>Exigir emprego para entrar na loja</span></label>
              <template v-if="draft.Requirement.Job.required"
                ><div class="data-card" v-for="(job, index) in draft.Requirement.Job.jobs" :key="index">
                  <div class="form-grid">
                    <label>Emprego<input v-model="job.name" /></label><label>Nome<input v-model="job.label" /></label
                    ><label>Grade mínima<input type="number" v-model.number="job.grade" min="0" /></label>
                    <div class="field-button"><button class="danger-text" @click="draft.Requirement.Job.jobs.splice(index, 1)">REMOVER EMPREGO</button></div>
                  </div>
                </div>
                <p v-if="!draft.Requirement.Job.jobs.length" class="muted">Adicione ao menos um emprego autorizado.</p></template
              >
            </section>
            <section class="settings-section">
              <div class="section-heading">
                <h3>Licença para entrar na loja</h3>
                <p>Independente das licenças exigidas para produtos específicos.</p>
              </div>
              <div class="switch-grid access-switches">
                <label class="toggle-option"><input type="checkbox" v-model="draft.Requirement.License.required" /><span>Exigir licença para entrar</span></label>
                <label class="toggle-option" :class="{ disabled: !draft.Requirement.License.required }"
                  ><input type="checkbox" v-model="draft.Requirement.License.buyDialog" :disabled="!draft.Requirement.License.required" /><span
                    >Permitir compra da licença</span
                  ></label
                >
              </div>
              <div v-if="draft.Requirement.License.required" class="form-grid">
                <label>Identificador da licença<input v-model="draft.Requirement.License.type" /></label>
                <label>Nome da licença<input v-model="draft.Requirement.License.label" /></label>
                <label>Preço<input type="number" min="0" v-model.number="draft.Requirement.License.price" /></label>
                <label
                  >Origem<select v-model="draft.Requirement.License.mode">
                    <option value="framework">Framework</option>
                    <option value="inventory">Documento no inventário</option>
                  </select></label
                >
              </div>
            </section>
            <section class="settings-section">
              <div class="section-heading">
                <h3>Emitir documento de licença</h3>
                <p>A emissão de documentos exige o ox_inventory.</p>
              </div>
              <div class="form-grid">
                <label>ID do jogador<input type="number" v-model="licenseTarget" /></label><label>Tipo da licença<input v-model="licenseType" placeholder="weapon" /></label>
                <div class="field-button"><button @click="issueLicense">EMITIR LICENÇA</button></div>
              </div>
            </section>
          </div>
          <footer class="editor-footer">
            <span :class="{ success: status.includes('salva') }">{{ status }}</span
            ><button class="delete-button" @click="deleteConfirm = !deleteConfirm">{{ deleteConfirm ? "CANCELAR" : "EXCLUIR LOJA" }}</button
            ><button v-if="deleteConfirm" class="danger-button" @click="remove">CONFIRMAR EXCLUSÃO</button>
          </footer>
        </section>
        <section v-else class="editor empty"><h2>Selecione ou crie uma loja</h2></section>
      </div>
    </div>
    <!-- Produto: edição ou cadastro -->
    <div v-if="itemModal && itemDraft" class="modal-backdrop" @click.self="closeProductDialogs">
      <section class="product-modal" role="dialog" aria-modal="true" aria-label="Configuração do produto">
        <div class="modal-heading">
          <div>
            <h2>{{ editedIndex === null ? "CADASTRAR PRODUTO" : "EDITAR PRODUTO" }}</h2>
            <p>Configure os dados exibidos na loja.</p>
          </div>
          <button class="icon-close" @click="closeProductDialogs" aria-label="Fechar">×</button>
        </div>
        <div class="modal-body">
          <div class="product-modal-preview">
            <div class="modal-preview-image"><img :key="itemDraft.name" :src="itemImage(itemDraft.name)" :alt="itemDraft.label" @error="onImageError" /></div>
            <div>
              <strong>{{ itemDraft.label || "Novo produto" }}</strong
              ><small>{{ itemDraft.name || "Selecione um item do inventário" }}</small>
            </div>
          </div>
          <button v-if="editedIndex === null" class="browse-button" @click="openCatalog"><Icon icon="mdi:magnify" /> PESQUISAR ITEM DA BASE (OX_INVENTORY)</button>
          <div class="form-grid">
            <label>Item (spawn)<input v-model="itemDraft.name" maxlength="64" placeholder="water" /></label>
            <label>Nome na loja<input v-model="itemDraft.label" maxlength="100" placeholder="Garrafa de água" /></label>
            <label
              >Categoria<select v-model="itemDraft.category">
                <option v-for="cat in draft.Categories" :key="cat.type" :value="cat.type">{{ cat.name }}</option>
              </select></label
            >
            <label>Preço<input type="number" v-model.number="itemDraft.price" min="0" max="100000000" step="1" /></label>
          </div>
          <label class="toggle-option"><input type="checkbox" v-model="itemDraft.license.required" /><span>Exigir licença para comprar este produto</span></label>
          <div v-if="itemDraft.license.required" class="form-grid">
            <label>Tipo da licença<input v-model="itemDraft.license.type" maxlength="64" /></label>
            <label
              >Origem da licença<select v-model="itemDraft.license.mode">
                <option value="framework">Framework</option>
                <option value="inventory">Documento no inventário</option>
              </select></label
            >
          </div>
          <p v-if="itemError" class="form-error">{{ itemError }}</p>
        </div>
        <div class="modal-actions">
          <button @click="closeProductDialogs">CANCELAR</button
          ><button class="save-button" @click="saveProduct">{{ editedIndex === null ? "ADICIONAR PRODUTO" : "APLICAR ALTERAÇÕES" }}</button>
        </div>
      </section>
    </div>
    <!-- Catálogo de itens: somente ox_inventory -->
    <div v-if="browseModal" class="modal-backdrop modal-top" @click.self="browseModal = false">
      <section class="catalog-modal" role="dialog" aria-modal="true" aria-label="Itens do ox_inventory">
        <div class="modal-heading">
          <div>
            <h2>CATÁLOGO DE ITENS</h2>
            <p>Itens registrados no ox_inventory.</p>
          </div>
          <button class="icon-close" @click="browseModal = false" aria-label="Fechar">×</button>
        </div>
        <input v-model="catalogQuery" class="search" placeholder="Pesquisar pelo nome ou identificador..." @input="catalogLimit = 100" />
        <p v-if="catalogLoading" class="muted">Carregando itens...</p>
        <p v-else-if="catalogError" class="form-error">
          {{ catalogError }}
          <button @click="((catalogLoaded = false), loadCatalog())">TENTAR NOVAMENTE</button>
        </p>
        <template v-else-if="inventoryAvailable"
          ><p class="muted">{{ catalogFiltered.length }} itens encontrados</p>
          <div class="catalog-list">
            <button v-for="item in catalogVisible" :key="item.name" class="catalog-choice" @click="selectCatalogItem(item)">
              <img :src="itemImage(item.name)" :alt="item.label" @error="onImageError" /><span
                ><strong>{{ item.label }}</strong
                ><small>{{ item.name }}</small></span
              ><Icon icon="mdi:plus" />
            </button>
          </div>
          <button v-if="catalogFiltered.length > catalogVisible.length" class="load-more" @click="catalogLimit += 100">
            MOSTRAR MAIS ({{ catalogFiltered.length - catalogVisible.length }} RESTANTES)
          </button>
          <p v-if="!catalogFiltered.length" class="muted">Nenhum item encontrado.</p>
        </template>
      </section>
    </div>
    <!-- Exclusão confirmada, sem salvar imediatamente no servidor -->
    <div v-if="deleteItemModal" class="modal-backdrop modal-top" @click.self="deleteItemModal = false">
      <section class="confirm-modal" role="alertdialog" aria-modal="true" aria-label="Confirmar exclusão do produto">
        <div class="modal-heading">
          <h2>EXCLUIR PRODUTO</h2>
          <button class="icon-close" @click="deleteItemModal = false" aria-label="Fechar">×</button>
        </div>
        <p>
          Deseja remover <strong>{{ deletingIndex !== null ? draft.Items[deletingIndex]?.label : "" }}</strong> da loja? A exclusão só será publicada após clicar em
          <strong>Salvar alterações</strong>.
        </p>
        <div class="modal-actions">
          <button @click="deleteItemModal = false">CANCELAR</button><button class="danger-button" @click="confirmDeleteProduct">EXCLUIR PRODUTO</button>
        </div>
      </section>
    </div>
  </main>
</template>

<style scoped>
.manager-container {
  position: absolute;
  inset: 0;
  z-index: 90;
  width: 100vw;
  height: 100vh;
  background: rgba(10, 10, 10, 0.97);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: "PFDinDisplayPro Medium", sans-serif;
}
.manager-layout {
  width: 90vw;
  height: 85vh;
  display: flex;
  flex-direction: column;
  gap: 2vh;
}
.manager-header,
.manager-content,
.row-line,
.editor-header,
.editor-footer,
.heading,
.create-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1vw;
}
.manager-header {
  padding-bottom: 1.5vh;
  border-bottom: 1px solid #343434;
}
.heading {
  justify-content: flex-start;
}
.heading h1 {
  font-family: "PFDinDisplayPro Bold", sans-serif;
  font-size: 2.8vh;
  letter-spacing: 0.06em;
}
.heading span {
  padding: 0.7vh 1.7vh;
  background: #3f3f3f;
  border-radius: 0.35vh;
  font-size: 1.4vh;
}
.manager-header p,
.sidebar small,
.editor-header p,
.muted {
  color: #888;
  font-size: 1.4vh;
}
.manager-content {
  flex: 1;
  min-height: 0;
  align-items: stretch;
  gap: 1.3vw;
}
.sidebar {
  width: 22%;
  background: #1e1e1e;
  border-radius: 0.5vh;
  padding: 2vh;
  overflow: auto;
  display: flex;
  flex-direction: column;
  gap: 1vh;
}
.sidebar h2,
.editor h2 {
  font-family: "PFDinDisplayPro Bold", sans-serif;
  font-size: 2vh;
}
.store-choice {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  padding: 1.4vh;
  border: 1px solid #323232;
  background: #2d2d2d;
  border-radius: 0.5vh;
  text-align: left;
}
.store-choice.active,
.tabs .active {
  background: #fff;
  color: #111;
}
.store-choice.active small {
  color: #444;
}
.store-choice strong {
  font-size: 1.6vh;
}
.store-choice small {
  margin-top: 0.35vh;
}
.create-row {
  margin-top: 1vh;
}
.create-row input {
  min-width: 0;
  flex: 1;
}
.create-row button {
  font-size: 2.4vh;
}
.editor {
  width: 78%;
  display: flex;
  flex-direction: column;
  min-height: 0;
  padding: 2vh;
  background: #1e1e1e;
  border-radius: 0.5vh;
}
.editor.empty {
  justify-content: center;
  align-items: center;
}
.editor-header {
  align-items: center;
}
.editor-header h2 {
  font-size: 2.5vh;
}
.editor-header p {
  font-size: 1.4vh;
}
.tabs {
  display: flex;
  gap: 0.8vw;
  border-bottom: 1px solid #343434;
  padding-bottom: 1vh;
  margin-top: 2vh;
}
.tabs button {
  padding: 1vh 1.3vw;
  background: #303030;
  border-radius: 0.5vh;
  white-space: nowrap;
}
.scroll-panel {
  overflow: auto;
  flex: 1;
  padding: 2vh 0.5vw 2vh 0;
  display: flex;
  flex-direction: column;
  gap: 1.5vh;
  min-height: 0;
}
.scroll-panel h3 {
  font-family: "PFDinDisplayPro Bold", sans-serif;
  font-size: 1.8vh;
}
.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1.5vh;
}
.form-grid label,
.coordinate-grid label,
.category-edit label {
  display: flex;
  flex-direction: column;
  gap: 0.65vh;
  color: #aaa;
  font-size: 1.3vh;
}
.form-grid .wide {
  grid-column: 1/-1;
}
input:not([type="checkbox"]),
select,
textarea {
  width: 100%;
  background: #303030;
  border: 1px solid #404040;
  color: #fff;
  padding: 1.2vh;
  border-radius: 0.5vh;
  font: inherit;
  font-size: 1.5vh;
  outline: 0;
}
textarea {
  resize: vertical;
}
input:focus,
select:focus,
textarea:focus {
  border-color: #aaa;
}
input[type="checkbox"] {
  accent-color: #fff;
  vertical-align: middle;
}
.switch-row {
  display: flex;
  flex-wrap: wrap;
  gap: 2vw;
  grid-column: 1/-1;
}
.switch-row label {
  display: inline;
}
button {
  font: inherit;
  color: #fff;
  cursor: pointer;
  border: none;
  outline: 0;
  background: #303030;
  border-radius: 0.5vh;
  padding: 1vh 1.35vw;
  transition: background 0.15s;
  font-size: 1.35vh;
}
button:hover:not(:disabled) {
  background: #555;
}
button:disabled {
  opacity: 0.45;
  cursor: default;
}
.save-button {
  background: #fff;
  color: #111;
  font-family: "PFDinDisplayPro Bold", sans-serif;
}
.save-button:hover:not(:disabled) {
  background: #ddd;
}
.close {
  font-size: 2.5vh;
  background: transparent;
}
.row-line {
  margin-bottom: 0.5vh;
}
.data-card {
  background: #252525;
  border: 1px solid #343434;
  border-radius: 0.5vh;
  padding: 1.5vh;
  display: flex;
  flex-direction: column;
  gap: 1.2vh;
}
.coordinate-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.6vw;
}
.category-edit {
  display: grid;
  grid-template-columns: 5vh 1fr 1.5fr 1.6fr auto;
  align-items: center;
  gap: 1vw;
}
.icon-preview {
  width: 5vh;
  height: 5vh;
  border-radius: 0.5vh;
  background: #303030;
  display: grid;
  place-items: center;
}
.icon-preview img {
  width: 60%;
  height: 60%;
  filter: invert(1);
}
.danger-text {
  background: transparent;
  color: #ec8585;
}
.danger-text:hover:not(:disabled) {
  background: #613535;
}
.search {
  margin-bottom: 1vh;
}
.editor-footer {
  margin-top: 1vh;
  border-top: 1px solid #333;
  padding-top: 1.5vh;
  min-height: 5vh;
}
.editor-footer span {
  color: #dca2a2;
  flex: 1;
  font-size: 1.4vh;
}
.editor-footer .success {
  color: #66f96f;
}
.delete-button,
.danger-button {
  background: #803434;
}
.danger-button {
  background: #ad3d3d;
}

/* Manager v2 - alinhamento */
.settings-section {
  background: #252525;
  border: 1px solid #353535;
  border-radius: 0.55vh;
  padding: 1.8vh;
  display: flex;
  flex-direction: column;
  gap: 1.7vh;
  width: 100%;
  min-width: 0;
}
.section-heading {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.4vh;
}
.section-heading p,
.row-line .muted {
  font-size: 1.3vh;
  color: #888;
}
.settings-section .form-grid {
  width: 100%;
  align-items: end;
  column-gap: 1.5vh;
  row-gap: 1.5vh;
}
.form-grid > label {
  min-width: 0;
}
.switch-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1vh;
  width: 100%;
}
.toggle-option,
.form-grid label.toggle-option {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: flex-start;
  gap: 0.8vh;
  min-height: 4.5vh;
  color: #ddd;
  font-size: 1.35vh;
  border: 1px solid #3b3b3b;
  border-radius: 0.5vh;
  padding: 1vh 1.2vh;
  background: #2f2f2f;
  cursor: pointer;
  line-height: 1.35;
}
.toggle-option input[type="checkbox"],
.form-grid label.toggle-option input[type="checkbox"] {
  display: block;
  appearance: none;
  -webkit-appearance: none;
  width: 1.65vh;
  height: 1.65vh;
  min-width: 1.65vh;
  min-height: 1.65vh;
  margin: 0;
  flex: 0 0 auto;
  cursor: pointer;
  border: 1px solid #777;
  border-radius: 0.3vh;
  background: #222;
  position: relative;
}
.toggle-option input[type="checkbox"]:checked {
  background: #fff;
  border-color: #fff;
}
.toggle-option input[type="checkbox"]:checked:after {
  content: "";
  position: absolute;
  width: 0.5vh;
  height: 0.85vh;
  border: solid #111;
  border-width: 0 0.2vh 0.2vh 0;
  top: 0.18vh;
  left: 0.48vh;
  transform: rotate(45deg);
}
.toggle-option:has(input:checked) {
  border-color: #777;
  background: #343434;
}
.toggle-option.disabled {
  opacity: 0.55;
  cursor: default;
}
.field-button {
  display: flex;
  align-items: end;
  justify-content: flex-start;
}
.field-button button {
  min-height: 4.4vh;
  width: 100%;
}
/* Grade de produtos */
.product-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(17vh, 1fr));
  gap: 1.45vh;
  align-content: start;
  width: 100%;
}
.product-card {
  background: #252525;
  border: 1px solid #393939;
  border-radius: 0.55vh;
  min-height: 24vh;
  padding: 1.25vh;
  display: flex;
  flex-direction: column;
  gap: 0.65vh;
  cursor: pointer;
  outline: none;
  transition:
    background 0.18s,
    border-color 0.18s,
    transform 0.18s,
    box-shadow 0.18s;
}
.product-card:hover,
.product-card:focus-visible {
  background: #303030;
  border-color: #eee;
  transform: translateY(-0.3vh);
  box-shadow: 0 0.5vh 1.7vh #0005;
}
.product-card-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  min-height: 3vh;
}
.price-tag {
  font-size: 1.32vh;
  font-family: "PFDinDisplayPro Bold", sans-serif;
  color: #66f96f;
}
button.product-delete {
  display: grid;
  place-items: center;
  color: #eb9999;
  background: #3b2b2b;
  border: 1px solid #644040;
  border-radius: 0.5vh;
  padding: 0.5vh;
  width: 2.9vh;
  height: 2.9vh;
  font-size: 1.6vh;
}
button.product-delete:hover {
  background: #8a3434;
  color: #fff;
}
.product-image {
  display: grid;
  place-items: center;
  height: 13vh;
  min-height: 0;
  background: radial-gradient(ellipse, #ffffff19 0%, transparent 70%);
}
.product-image img {
  max-width: 84%;
  max-height: 11vh;
  object-fit: contain;
  display: block;
}
.product-name {
  margin-top: auto;
  font-family: "PFDinDisplayPro Bold", sans-serif;
  color: #fff;
  font-size: 1.55vh;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.product-id {
  font-size: 1.15vh;
  color: #888;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.empty-products {
  padding: 3vh;
  text-align: center;
  background: #252525;
  border-radius: 0.5vh;
  color: #999;
}
/* Modais */
.modal-backdrop {
  position: absolute;
  inset: 0;
  z-index: 100;
  background: #000c;
  display: grid;
  place-items: center;
  padding: 3vh;
}
.modal-backdrop.modal-top {
  z-index: 110;
}
.product-modal,
.catalog-modal,
.confirm-modal {
  width: min(78vh, 94vw);
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  background: #1e1e1e;
  border: 1px solid #414141;
  border-radius: 0.7vh;
  padding: 2.5vh;
  gap: 2vh;
  box-shadow: 0 2vh 8vh #000b;
  min-height: 0;
}
.catalog-modal {
  width: min(90vh, 94vw);
  height: min(75vh, 90vh);
}
.confirm-modal {
  width: min(55vh, 94vw);
}
.modal-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 2vh;
  border-bottom: 1px solid #353535;
  padding-bottom: 1.5vh;
}
.modal-heading h2 {
  font-family: "PFDinDisplayPro Bold", sans-serif;
  font-size: 2.25vh;
  color: #fff;
}
.modal-heading p {
  font-size: 1.3vh;
  color: #888;
  margin-top: 0.35vh;
}
button.icon-close {
  background: none;
  font-size: 2.5vh;
  line-height: 1;
  padding: 0.2vh 0.6vh;
}
.modal-body {
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  min-height: 0;
  gap: 1.5vh;
  padding-right: 0.4vh;
}
.modal-body .form-grid {
  align-items: end;
}
.modal-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 1vh;
  padding-top: 1.3vh;
  border-top: 1px solid #353535;
}
.product-modal-preview {
  display: flex;
  gap: 1.5vh;
  align-items: center;
  background: #252525;
  padding: 1vh;
  border-radius: 0.5vh;
}
.product-modal-preview strong,
.product-modal-preview small {
  display: block;
}
.product-modal-preview small {
  color: #999;
  font-size: 1.25vh;
}
.modal-preview-image {
  background: radial-gradient(ellipse, #ffffff20, transparent);
  width: 9vh;
  height: 9vh;
  display: grid;
  place-items: center;
}
.modal-preview-image img {
  max-width: 90%;
  max-height: 80%;
  object-fit: contain;
}
.browse-button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75vh;
  min-height: 4.5vh;
  border: 1px dashed #6f6f6f;
}
.form-error {
  color: #ff9999;
  font-size: 1.4vh;
}
.catalog-list {
  flex: 1;
  overflow: auto;
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-content: start;
  gap: 1vh;
  padding-right: 0.5vh;
}
button.catalog-choice {
  display: flex;
  align-items: center;
  justify-content: space-between;
  text-align: left;
  gap: 1vh;
  border: 1px solid #3b3b3b;
  padding: 1vh;
  background: #252525;
  min-width: 0;
  min-height: 6.5vh;
}
.catalog-choice img {
  width: 4.5vh;
  height: 4.5vh;
  object-fit: contain;
  flex: none;
}
.catalog-choice span {
  flex: 1;
  min-width: 0;
}
.catalog-choice strong,
.catalog-choice small {
  display: block;
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
}
.catalog-choice small {
  color: #888;
  font-size: 1.2vh;
  margin-top: 0.35vh;
}
.catalog-choice:hover {
  border-color: #aaa;
  background: #323232;
}
.load-more {
  width: 100%;
}
.confirm-modal p {
  color: #bbb;
  font-size: 1.5vh;
  line-height: 1.55;
}
.confirm-modal p strong {
  color: #fff;
}
@media (max-width: 1100px) {
  .switch-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .product-grid {
    grid-template-columns: repeat(auto-fill, minmax(16vh, 1fr));
  }
}
</style>
