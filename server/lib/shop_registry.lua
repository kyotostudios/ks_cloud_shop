local Config = require('config.main')
local settings = Config.ShopManager or {}
local enabled = settings.enabled == true
local cache, ready, healthy = {}, false, true

local function plain(value)
    local kind = type(value)
    if kind == 'vector2' or kind == 'vector3' or kind == 'vector4' then
        local out = { x = value.x, y = value.y }
        if value.z then out.z = value.z end
        if value.w then out.w = value.w end
        return out
    end
    if kind ~= 'table' then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = plain(child) end
    return out
end
local function copy(value) return json.decode(json.encode(plain(value))) end
local function validString(value, max)
    return type(value) == 'string' and #value > 0 and #value <= max
end
local function num(value, min, max)
    return type(value) == 'number' and value == value and value >= min and value <= max
end
local function validSlug(value)
    return validString(value, 64) and value:match('^[%w_%-]+$') ~= nil
end
local function normalize(key, input)
    if not validSlug(key) or type(input) ~= 'table' then return nil, 'Identificador inválido' end
    local origin = Config.Shops[key] or Config.Shops.shop or next(Config.Shops) and select(2, next(Config.Shops))
    if not origin then return nil, 'Nenhuma loja-modelo disponível' end
    local result = copy(origin)
    if type(input.Locales) == 'table' then
        for _, section in ipairs({ 'MainHeader', 'CartHeader' }) do
            local src = input.Locales[section]
            if type(src) == 'table' then
                result.Locales[section] = result.Locales[section] or {}
                for _, field in ipairs({ 'title', 'tag', 'description' }) do
                    local v = src[field]
                    if type(v) == 'string' and #v <= 500 then result.Locales[section][field] = v end
                end
            end
        end
    end
    result.PointRadius = num(input.PointRadius, 2, 250) and input.PointRadius or result.PointRadius
    result.Locations = {}
    if type(input.Locations) ~= 'table' or #input.Locations > 100 then return nil, 'Localizações inválidas' end
    for _, pos in ipairs(input.Locations) do
        if type(pos) ~= 'table' or not num(pos.x, -10000, 10000) or not num(pos.y, -10000, 10000) or not num(pos.z, -1000, 5000) or not num(pos.w, -360, 360) then
            return nil, 'Coordenadas inválidas'
        end
        result.Locations[#result.Locations + 1] = { x = pos.x, y = pos.y, z = pos.z, w = pos.w }
    end
    if #result.Locations == 0 then return nil, 'Adicione uma localização' end
    result.Categories = { { name = 'All Products', type = 'all', icon = 'local:layout-grid' } }
    local cats = { all = true }
    if type(input.Categories) ~= 'table' or #input.Categories > 80 then return nil, 'Categorias inválidas' end
    for _, cat in ipairs(input.Categories) do
        if type(cat) ~= 'table' or not validSlug(cat.type) or not validString(cat.name, 70) or not validString(cat.icon, 100) then return nil, 'Categoria inválida' end
        if cat.type == 'all' then
            result.Categories[1] = { type = 'all', name = cat.name, icon = cat.icon }
        elseif cats[cat.type] then return nil, 'Categoria duplicada'
        else
            cats[cat.type] = true
            result.Categories[#result.Categories + 1] = { type = cat.type, name = cat.name, icon = cat.icon }
        end
    end
    result.Items = {}
    local items = {}
    if type(input.Items) ~= 'table' or #input.Items > 1000 then return nil, 'Produtos inválidos' end
    for _, item in ipairs(input.Items) do
        if type(item) ~= 'table' or not validSlug(item.name) or not validString(item.label, 100) or not cats[item.category] or not num(item.price, 0, 100000000) or item.price % 1 ~= 0 then
            return nil, 'Produto, categoria ou preço inválido'
        end
        if items[item.name] then return nil, 'Produto duplicado' end
        items[item.name] = true
        local entry = { name = item.name, label = item.label, category = item.category, price = item.price }
        if type(item.license) == 'table' and item.license.required == true then
            local lic = item.license
            if not validSlug(lic.type) or (lic.mode ~= 'framework' and lic.mode ~= 'inventory') then return nil, 'Licença de produto inválida' end
            entry.license = { required = true, type = lic.type, mode = lic.mode }
        end
        result.Items[#result.Items + 1] = entry
    end
    local requirements = input.Requirement or {}
    local job = requirements.Job or {}
    result.Requirement.Job.required = job.required == true
    if type(job.jobs) == 'table' then
        if #job.jobs > 30 then return nil, 'Muitos empregos' end
        result.Requirement.Job.jobs = {}
        for _, j in ipairs(job.jobs) do
            if not validSlug(j.name) or not validString(j.label, 80) or not num(j.grade, 0, 1000) then return nil, 'Emprego inválido' end
            result.Requirement.Job.jobs[#result.Requirement.Job.jobs + 1] = { name = j.name, label = j.label, grade = j.grade }
        end
    end
    local license = requirements.License or {}
    result.Requirement.License.required = license.required == true
    result.Requirement.License.buyDialog = license.buyDialog == true
    result.Requirement.License.mode = license.mode == 'inventory' and 'inventory' or 'framework'
    if not validSlug(license.type) or not validString(license.label, 100) or not num(license.price, 0, 100000000) or license.price % 1 ~= 0 then return nil, 'Licença da loja inválida' end
    result.Requirement.License.type, result.Requirement.License.label, result.Requirement.License.price = license.type, license.label, license.price
    if type(input.Blip) == 'table' then
        local b = input.Blip
        result.Blip.enabled = b.enabled == true
        if type(b.name) == 'string' and #b.name <= 90 then result.Blip.name = b.name end
        if num(b.sprite, 0, 1000) then result.Blip.sprite = b.sprite end
        if num(b.color, 0, 100) then result.Blip.color = b.color end
        if num(b.scale, 0.1, 2.0) then result.Blip.scale = b.scale end
    end
    if type(input.Indicator) == 'table' and type(input.Indicator.Ped) == 'table' then
        local p = input.Indicator.Ped
        result.Indicator.Ped.enabled = p.enabled == true
        if type(p.model) == 'string' and validSlug(p.model) then result.Indicator.Ped.model = tonumber(p.model) or joaat(p.model) end
        if num(p.model, 0, 4294967295) then result.Indicator.Ped.model = p.model end
        if type(p.scenario) == 'string' and #p.scenario <= 100 then result.Indicator.Ped.scenario = p.scenario end
    end
    if type(input.Indicator) == 'table' and type(input.Indicator.Marker) == 'table' then
        result.Indicator.Marker.enabled = input.Indicator.Marker.enabled == true
    end
    if type(input.Interaction) == 'table' then
        for _, mode in ipairs({ 'HelpText', 'FloatingText', 'Target' }) do
            if type(input.Interaction[mode]) == 'table' then
                result.Interaction[mode].enabled = input.Interaction[mode].enabled == true
            end
        end
    end
    return result
end
local function loadData()
    if not enabled then cache = Config.Shops; ready = true; return end
    if GetResourceState('oxmysql') ~= 'started' then
        healthy, ready = false, true
        print('^1[cloud-shop] ShopManager requer oxmysql iniciado^7')
        return
    end
    local ok, err = pcall(function()
        exports.oxmysql:query_async([[CREATE TABLE IF NOT EXISTS cloud_shop_stores (shop_key VARCHAR(64) PRIMARY KEY, data_json LONGTEXT NOT NULL)]])
        local rows = exports.oxmysql:query_async('SELECT shop_key, data_json FROM cloud_shop_stores') or {}
        local seeded = false
        for _, row in ipairs(rows) do
            if row.shop_key == '__initialized__' then seeded = true
            else
                local decoded = json.decode(row.data_json)
                local validated, reason = normalize(row.shop_key, decoded)
                if validated then cache[row.shop_key] = validated else print(('[cloud-shop] Loja ignorada %s: %s'):format(row.shop_key, reason)) end
            end
        end
        if not seeded then
            for key, shop in pairs(Config.Shops) do
                local validated = normalize(key, plain(shop))
                if validated then
                    exports.oxmysql:query_async('INSERT INTO cloud_shop_stores (shop_key, data_json) VALUES (?, ?) ON DUPLICATE KEY UPDATE data_json = VALUES(data_json)', { key, json.encode(validated) })
                    cache[key] = validated
                end
            end
            exports.oxmysql:query_async('INSERT INTO cloud_shop_stores (shop_key, data_json) VALUES (?, ?)', { '__initialized__', '{}' })
        end
    end)
    if not ok then healthy = false; print('[cloud-shop] Falha ao carregar lojas: ' .. tostring(err)) end
    ready = true
end
CreateThread(loadData)
local Registry = {}
function Registry.Enabled() return enabled end
function Registry.Ready()
    while not ready do Wait(50) end
    return healthy
end
function Registry.All()
    if not Registry.Ready() then return {} end
    return copy(cache)
end
function Registry.Get(key)
    if not Registry.Ready() then return nil end
    return cache[key]
end
function Registry.Save(key, data)
    if not enabled or not Registry.Ready() or key == '__initialized__' then return false, 'Modo in-game indisponível' end
    local normalized, reason = normalize(key, data)
    if not normalized then return false, reason end
    local ok, err = pcall(function()
        exports.oxmysql:query_async('INSERT INTO cloud_shop_stores (shop_key, data_json) VALUES (?, ?) ON DUPLICATE KEY UPDATE data_json = VALUES(data_json)', { key, json.encode(normalized) })
    end)
    if not ok then return false, tostring(err) end
    cache[key] = normalized
    TriggerClientEvent('cloud-shop:syncShops', -1, Registry.All())
    return true
end
function Registry.Delete(key)
    if not enabled or not Registry.Ready() or not cache[key] then return false, 'Loja não encontrada' end
    local ok, err = pcall(function()
        exports.oxmysql:query_async('DELETE FROM cloud_shop_stores WHERE shop_key = ?', { key })
    end)
    if not ok then return false, tostring(err) end
    cache[key] = nil
    TriggerClientEvent('cloud-shop:syncShops', -1, Registry.All())
    return true
end
function Registry.Template()
    return copy(Config.Shops.shop or select(2, next(Config.Shops)))
end
return Registry
