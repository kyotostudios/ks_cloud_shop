<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { callback } from '@/utils/callback'
import { categoryIcons, resolveCategoryIcon } from '@/utils/categoryIcons'
import { useManagerStore } from '@/stores/manager'
const manager = useManagerStore()
const shops = ref<Record<string, any>>({})
const template = ref<any>(null)
const selected = ref('')
const draft = ref<any>(null)
const newKey = ref('')
const tab = ref<'general' | 'positions' | 'categories' | 'items' | 'access'>('general')
const search = ref('')
const status = ref('')
const busy = ref(false)
const deleteConfirm = ref(false)
const licenseTarget = ref('')
const licenseType = ref('')
const clone = (value: any) => JSON.parse(JSON.stringify(value))
const keys = computed(() => Object.keys(shops.value).sort())
const tabs = [['general','Geral'],['positions','Localizações'],['categories','Categorias'],['items','Produtos'],['access','Licenças e acesso']] as const
const completeDraft = (value: any) => {
  for (const item of value.Items ?? []) item.license ??= { required: false, mode: 'framework', type: 'weapon' }
  value.Requirement.License.mode ??= 'framework'
  return value
}
const displayedItems = computed(() => (draft.value?.Items ?? []).filter((p: any) => `${p.name} ${p.label}`.toLowerCase().includes(search.value.toLowerCase())))
const close = async () => { await callback({ action: 'manager:close' }); manager.showManager = false }
const load = async () => {
  const result = await callback({ action: 'manager:data' })
  if (!result?.shops) { status.value = 'Não foi possível carregar as lojas.'; return }
  shops.value = result.shops
  template.value = result.template
  if (selected.value && shops.value[selected.value]) select(selected.value)
  else if (!draft.value && keys.value.length) select(keys.value[0])
}
const select = (key: string) => {
  selected.value = key
  draft.value = completeDraft(clone(shops.value[key]))
  deleteConfirm.value = false
  status.value = ''
  tab.value = 'general'
}
const create = () => {
  const key = newKey.value.trim().toLowerCase()
  if (!/^[a-z0-9_-]{1,64}$/.test(key)) { status.value = 'ID inválido. Use letras, números, _ ou -.'; return }
  if (shops.value[key]) { status.value = 'Essa loja já existe.'; return }
  selected.value = key
  draft.value = completeDraft(clone(template.value))
  draft.value.Locales.MainHeader.title = key.replace(/_/g, ' ')
  draft.value.Locations = []
  status.value = 'Nova loja: configure uma localização e clique em salvar.'
  tab.value = 'general'
  newKey.value = ''
}
const save = async () => {
  if (!draft.value || busy.value) return
  busy.value = true
  try {
    const result = await callback({ action: 'manager:save', key: selected.value, shop: draft.value })
    status.value = result?.success ? 'Loja salva e sincronizada.' : (result?.reason || 'Erro ao salvar a loja.')
    if (result?.success) { const message = status.value; await load(); status.value = message }
  } finally { busy.value = false }
}
const remove = async () => {
  if (!deleteConfirm.value || busy.value) return
  busy.value = true
  try {
    const result = await callback({ action: 'manager:delete', key: selected.value })
    status.value = result?.success ? 'Loja excluída.' : (result?.reason || 'Erro ao excluir.')
    if (result?.success) {
      selected.value = ''
      draft.value = null
      await load()
    }
  } finally { busy.value = false; deleteConfirm.value = false }
}
const addPosition = async () => {
  const pos = await callback({ action: 'manager:position' })
  if (pos?.x !== undefined) draft.value.Locations.push(pos)
}
const addCategory = () => {
  const id = `category_${Date.now().toString(36)}`
  draft.value.Categories.push({ type: id, name: 'Nova categoria', icon: categoryIcons[0]?.id || 'ic:round-clear-all' })
}
const removeCategory = (index: number) => {
  const category = draft.value.Categories[index]
  if (category.type === 'all' || draft.value.Items.some((i: any) => i.category === category.type)) { status.value = 'Remova ou mova os produtos dessa categoria primeiro.'; return }
  draft.value.Categories.splice(index, 1)
}
const addItem = () => {
  const category = draft.value.Categories.find((c: any) => c.type !== 'all')?.type || 'all'
  draft.value.Items.push({ name: `new_item_${Date.now().toString(36)}`, label: 'Novo produto', category, price: 100, license: { required: false, mode: 'framework', type: 'weapon' } })
}
const issueLicense = async () => {
  const result = await callback({ action: 'manager:grantLicense', target: Number(licenseTarget.value), licenseType: licenseType.value })
  status.value = result?.reason || 'Falha ao emitir licença.'
}
onMounted(load)
</script>

<template>
  <main class="manager-container">
    <div class="manager-layout">
      <header class="manager-header">
        <div><div class="heading"><h1>SHOP MANAGER</h1><span>ADMIN</span></div><p>Gerenciamento de lojas, produtos e licenças</p></div>
        <button class="close" @click="close" aria-label="Fechar">×</button>
      </header>
      <div class="manager-content">
        <aside class="sidebar">
          <h2>LOJAS</h2>
          <button v-for="key in keys" :key="key" class="store-choice" :class="{ active: selected === key }" @click="select(key)">
            <strong>{{ shops[key]?.Locales?.MainHeader?.title || key }}</strong><small>{{ key }}</small>
          </button>
          <div class="create-row"><input v-model="newKey" placeholder="id_da_nova_loja" maxlength="64" @keyup.enter="create"><button @click="create">+</button></div>
          <p class="muted">O identificador não poderá ser alterado depois de criado.</p>
        </aside>
        <section class="editor" v-if="draft">
          <div class="editor-header"><div><h2>{{ draft.Locales.MainHeader.title }}</h2><p>{{ selected }}</p></div><button class="save-button" :disabled="busy" @click="save">SALVAR ALTERAÇÕES</button></div>
          <nav class="tabs">
            <button v-for="section in tabs" :key="section[0]" :class="{active: tab === section[0]}" @click="tab=section[0]">{{ section[1] }}</button>
          </nav>
          <div class="scroll-panel" v-if="tab === 'general'">
            <div class="form-grid">
              <label>Título da loja<input v-model="draft.Locales.MainHeader.title" maxlength="500"></label>
              <label>Etiqueta do título<input v-model="draft.Locales.MainHeader.tag" maxlength="500"></label>
              <label class="wide">Descrição da loja<textarea v-model="draft.Locales.MainHeader.description" rows="3" maxlength="500" /></label>
              <label>Título do carrinho<input v-model="draft.Locales.CartHeader.title" maxlength="500"></label>
              <label>Etiqueta do carrinho<input v-model="draft.Locales.CartHeader.tag" maxlength="500"></label>
              <label class="wide">Descrição do carrinho<textarea v-model="draft.Locales.CartHeader.description" rows="2" maxlength="500" /></label>
              <label>Nome do blip<input v-model="draft.Blip.name" maxlength="90"></label>
              <label>Sprite do blip<input type="number" v-model.number="draft.Blip.sprite" min="0" max="1000"></label>
              <label>Cor do blip<input type="number" v-model.number="draft.Blip.color" min="0" max="100"></label>
              <label>Escala do blip<input type="number" v-model.number="draft.Blip.scale" min="0.1" max="2" step="0.1"></label>
              <label>Raio de streaming<input type="number" v-model.number="draft.PointRadius" min="2" max="250"></label>
              <label>Modelo do ped (nome ou hash)<input v-model="draft.Indicator.Ped.model"></label>
              <label>Cenário do ped<input v-model="draft.Indicator.Ped.scenario"></label>
              <div class="switch-row"><label><input type="checkbox" v-model="draft.Blip.enabled"> Exibir blip</label><label><input type="checkbox" v-model="draft.Indicator.Ped.enabled"> Exibir ped</label><label><input type="checkbox" v-model="draft.Indicator.Marker.enabled"> Exibir marcador</label></div>
              <div class="switch-row"><label><input type="checkbox" v-model="draft.Interaction.HelpText.enabled"> Texto de ajuda</label><label><input type="checkbox" v-model="draft.Interaction.FloatingText.enabled"> Texto flutuante</label><label><input type="checkbox" v-model="draft.Interaction.Target.enabled"> ox_target</label></div>
            </div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'positions'">
            <div class="row-line"><h3>Localizações da loja</h3><button @click="addPosition">+ USAR POSIÇÃO ATUAL</button></div>
            <div class="data-card" v-for="(pos, index) in draft.Locations" :key="index"><div class="row-line"><strong>PONTO {{ index+1 }}</strong><button class="danger-text" @click="draft.Locations.splice(index,1)">REMOVER</button></div><div class="coordinate-grid"><label>X<input type="number" v-model.number="pos.x" step="0.0001"></label><label>Y<input type="number" v-model.number="pos.y" step="0.0001"></label><label>Z<input type="number" v-model.number="pos.z" step="0.0001"></label><label>Heading<input type="number" v-model.number="pos.w" step="0.01"></label></div></div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'categories'">
            <div class="row-line"><h3>Categorias</h3><button @click="addCategory">+ CATEGORIA</button></div>
            <div class="data-card" v-for="(cat, index) in draft.Categories" :key="index">
              <div class="category-edit"><div class="icon-preview"><img v-if="resolveCategoryIcon(cat.icon)" :src="resolveCategoryIcon(cat.icon)" alt="Ícone"></div><label>Identificador<input v-model="cat.type" :disabled="cat.type === 'all'"></label><label>Nome<input v-model="cat.name"></label><label>Ícone<select v-model="cat.icon"><option v-if="!categoryIcons.some(i => i.id === cat.icon)" :value="cat.icon">{{ cat.icon }} (legado)</option><option v-for="icon in categoryIcons" :value="icon.id" :key="icon.id">{{ icon.id.replace('local:','') }}</option></select></label><button class="danger-text" :disabled="cat.type === 'all'" @click="removeCategory(index)">EXCLUIR</button></div>
            </div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'items'">
            <div class="row-line"><h3>Produtos</h3><button @click="addItem">+ PRODUTO</button></div>
            <input class="search" v-model="search" placeholder="Pesquisar item pelo nome ou identificador...">
            <div class="data-card" v-for="item in displayedItems" :key="draft.Items.indexOf(item)">
              <div class="row-line"><strong>{{ item.name }}</strong><button class="danger-text" @click="draft.Items.splice(draft.Items.indexOf(item),1)">REMOVER</button></div>
              <div class="form-grid"><label>Item (spawn)<input v-model="item.name" maxlength="64"></label><label>Nome na loja<input v-model="item.label" maxlength="100"></label><label>Categoria<select v-model="item.category"><option v-for="cat in draft.Categories" :key="cat.type" :value="cat.type">{{ cat.name }}</option></select></label><label>Preço<input type="number" v-model.number="item.price" min="0" max="100000000"></label>
              <label><input type="checkbox" v-model="item.license.required"> Exigir licença</label><label>Tipo da licença<input v-model="item.license.type" :disabled="!item.license.required"></label><label>Origem da licença<select v-model="item.license.mode" :disabled="!item.license.required"><option value="framework">Framework</option><option value="inventory">Documento no inventário</option></select></label></div>
            </div>
          </div>
          <div class="scroll-panel" v-else-if="tab === 'access'">
            <h3>Requisitos de acesso à loja</h3>
            <div class="data-card form-grid"><label><input type="checkbox" v-model="draft.Requirement.Job.required"> Exigir emprego</label><button @click="draft.Requirement.Job.jobs.push({name:'police',label:'Polícia',grade:0})">+ EMPREGO</button></div>
            <div class="data-card" v-for="(job,index) in draft.Requirement.Job.jobs" :key="index"><div class="form-grid"><label>Emprego<input v-model="job.name"></label><label>Nome<input v-model="job.label"></label><label>Grade mínima<input type="number" v-model.number="job.grade" min="0"></label><button class="danger-text" @click="draft.Requirement.Job.jobs.splice(index,1)">REMOVER</button></div></div>
            <div class="data-card"><div class="form-grid"><label><input type="checkbox" v-model="draft.Requirement.License.required"> Exigir licença para entrar</label><label><input type="checkbox" v-model="draft.Requirement.License.buyDialog"> Permitir compra da licença</label><label>Identificador da licença<input v-model="draft.Requirement.License.type"></label><label>Nome da licença<input v-model="draft.Requirement.License.label"></label><label>Preço<input type="number" min="0" v-model.number="draft.Requirement.License.price"></label><label>Origem<select v-model="draft.Requirement.License.mode"><option value="framework">Framework</option><option value="inventory">Documento no inventário</option></select></label></div></div>
            <h3>Emitir documento de licença</h3>
            <div class="data-card form-grid"><label>ID do jogador<input type="number" v-model="licenseTarget"></label><label>Tipo da licença<input v-model="licenseType" placeholder="weapon"></label><button @click="issueLicense">EMITIR</button></div>
          </div>
          <footer class="editor-footer"><span :class="{ success: status.includes('salva') }">{{ status }}</span><button class="delete-button" @click="deleteConfirm = !deleteConfirm">{{ deleteConfirm ? 'CANCELAR' : 'EXCLUIR LOJA' }}</button><button v-if="deleteConfirm" class="danger-button" @click="remove">CONFIRMAR EXCLUSÃO</button></footer>
        </section>
        <section v-else class="editor empty"><h2>Selecione ou crie uma loja</h2></section>
      </div>
    </div>
  </main>
</template>

<style scoped>
.manager-container{position:absolute;inset:0;z-index:90;width:100vw;height:100vh;background:rgba(10,10,10,.97);color:#fff;display:flex;align-items:center;justify-content:center;font-family:'PFDinDisplayPro Medium',sans-serif}
.manager-layout{width:90vw;height:85vh;display:flex;flex-direction:column;gap:2vh}
.manager-header,.manager-content,.row-line,.editor-header,.editor-footer,.heading,.create-row{display:flex;align-items:center;justify-content:space-between;gap:1vw}
.manager-header{padding-bottom:1.5vh;border-bottom:1px solid #343434}
.heading{justify-content:flex-start}.heading h1{font-family:'PFDinDisplayPro Bold',sans-serif;font-size:2.8vh;letter-spacing:.06em}.heading span{padding:.7vh 1.7vh;background:#3f3f3f;border-radius:.35vh;font-size:1.4vh}
.manager-header p,.sidebar small,.editor-header p,.muted{color:#888;font-size:1.4vh}.manager-content{flex:1;min-height:0;align-items:stretch;gap:1.3vw}
.sidebar{width:22%;background:#1e1e1e;border-radius:.5vh;padding:2vh;overflow:auto;display:flex;flex-direction:column;gap:1vh}.sidebar h2,.editor h2{font-family:'PFDinDisplayPro Bold',sans-serif;font-size:2vh}
.store-choice{display:flex;flex-direction:column;align-items:flex-start;padding:1.4vh;border:1px solid #323232;background:#2d2d2d;border-radius:.5vh;text-align:left}.store-choice.active,.tabs .active{background:#fff;color:#111}.store-choice.active small{color:#444}.store-choice strong{font-size:1.6vh}.store-choice small{margin-top:.35vh}
.create-row{margin-top:1vh}.create-row input{min-width:0;flex:1}.create-row button{font-size:2.4vh}.editor{width:78%;display:flex;flex-direction:column;min-height:0;padding:2vh;background:#1e1e1e;border-radius:.5vh}.editor.empty{justify-content:center;align-items:center}.editor-header{align-items:center}.editor-header h2{font-size:2.5vh}.editor-header p{font-size:1.4vh}
.tabs{display:flex;gap:.8vw;border-bottom:1px solid #343434;padding-bottom:1vh;margin-top:2vh}.tabs button{padding:1vh 1.3vw;background:#303030;border-radius:.5vh;white-space:nowrap}
.scroll-panel{overflow:auto;flex:1;padding:2vh .5vw 2vh 0;display:flex;flex-direction:column;gap:1.5vh;min-height:0}.scroll-panel h3{font-family:'PFDinDisplayPro Bold',sans-serif;font-size:1.8vh}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1.5vh}.form-grid label,.coordinate-grid label,.category-edit label{display:flex;flex-direction:column;gap:.65vh;color:#aaa;font-size:1.3vh}.form-grid .wide{grid-column:1/-1}
input:not([type=checkbox]),select,textarea{width:100%;background:#303030;border:1px solid #404040;color:#fff;padding:1.2vh;border-radius:.5vh;font:inherit;font-size:1.5vh;outline:0}textarea{resize:vertical}input:focus,select:focus,textarea:focus{border-color:#aaa}input[type=checkbox]{accent-color:#fff;vertical-align:middle}.switch-row{display:flex;flex-wrap:wrap;gap:2vw;grid-column:1/-1}.switch-row label{display:inline}
button{font:inherit;color:#fff;cursor:pointer;border:none;outline:0;background:#303030;border-radius:.5vh;padding:1vh 1.35vw;transition:background .15s;font-size:1.35vh}button:hover:not(:disabled){background:#555}button:disabled{opacity:.45;cursor:default}.save-button{background:#fff;color:#111;font-family:'PFDinDisplayPro Bold',sans-serif}.save-button:hover:not(:disabled){background:#ddd}.close{font-size:2.5vh;background:transparent}.row-line{margin-bottom:.5vh}.data-card{background:#252525;border:1px solid #343434;border-radius:.5vh;padding:1.5vh;display:flex;flex-direction:column;gap:1.2vh}.coordinate-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:.6vw}.category-edit{display:grid;grid-template-columns:5vh 1fr 1.5fr 1.6fr auto;align-items:center;gap:1vw}.icon-preview{width:5vh;height:5vh;border-radius:.5vh;background:#303030;display:grid;place-items:center}.icon-preview img{width:60%;height:60%;filter:invert(1)}.danger-text{background:transparent;color:#ec8585}.danger-text:hover:not(:disabled){background:#613535}.search{margin-bottom:1vh}.editor-footer{margin-top:1vh;border-top:1px solid #333;padding-top:1.5vh;min-height:5vh}.editor-footer span{color:#dca2a2;flex:1;font-size:1.4vh}.editor-footer .success{color:#66f96f}.delete-button,.danger-button{background:#803434}.danger-button{background:#ad3d3d}
</style>
