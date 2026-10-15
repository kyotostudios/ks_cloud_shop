const assets = import.meta.glob('../assets/category-icons/*.svg', {
  eager: true,
  query: '?url',
  import: 'default',
}) as Record<string, string>

export const categoryIcons = Object.entries(assets).map(([path, url]) => ({
  id: `local:${path.split('/').pop()?.replace('.svg', '')}`,
  url,
})).sort((a, b) => a.id.localeCompare(b.id))
export const resolveCategoryIcon = (icon: string) => categoryIcons.find(entry => entry.id === icon)?.url ?? ''
