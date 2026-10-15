local Config = require('config.main')
local Functions = require('config.functions')
local Access = require('server.lib.shop_access')
local locales = lib.loadJson(('locales.%s'):format(Config.Locale))
local pending = {}
lib.callback.register('cloud-shop:processTransaction', function(source, paymentType, cart)
    if pending[source] then return false, 'Compra em andamento' end
    pending[source] = true
    local function process()
        local shopKey = Player(source).state.currentShop
        local allowed, shop = Access.Check(source, shopKey)
        if not allowed then return false, shop end
        if paymentType ~= 'cash' and paymentType ~= 'bank' then return false, 'Pagamento inválido' end
        if type(cart) ~= 'table' or #cart == 0 or #cart > 100 then return false, 'Carrinho inválido' end
        local catalog = {}
        for _, item in ipairs(shop.Items or {}) do catalog[item.name] = item end
        local valid, total, seen = {}, 0, {}
        for _, line in ipairs(cart) do
            if type(line) ~= 'table' or type(line.name) ~= 'string' or seen[line.name] then return false, 'Linha inválida' end
            local product = catalog[line.name]
            if not product then return false, 'Produto não encontrado' end
            if type(line.quantity) ~= 'number' or line.quantity % 1 ~= 0 or line.quantity < 1 or line.quantity > 999 then return false, 'Quantidade inválida' end
            if not Access.CheckItem(source, product) then
                local name = product.license and product.license.type or 'desconhecida'
                Functions.Notify.Server(source, { title = 'Licença necessária', description = 'Você precisa da licença ' .. name .. ' para comprar este produto.', type = 'error' })
                return false, 'Licença exigida: ' .. name
            end
            seen[line.name] = true
            total = total + product.price * line.quantity
            if total > 100000000 then return false, 'Limite excedido' end
            valid[#valid + 1] = { product = product, quantity = line.quantity }
        end
        if total < 0 then return false, 'Total inválido' end
        if (Bridge.GetMoney(source, paymentType) or 0) < total then return false, 'Saldo insuficiente' end
        if GetResourceState('ox_inventory') == 'started' then
            for _, entry in ipairs(valid) do
                if not exports.ox_inventory:CanCarryItem(source, entry.product.name, entry.quantity) then return false, 'Inventário cheio' end
            end
        end
        -- Cobra primeiro. Uma falha no AddItem devolve o valor daquela linha.
        -- Bloqueio evita carrinhos simultâneos do mesmo jogador.
        local purchased = 0
        local spent = 0
        for _, entry in ipairs(valid) do
            local cost = entry.product.price * entry.quantity
            if cost > 0 and (Bridge.GetMoney(source, paymentType) or 0) < cost then break end
            if cost > 0 and not Bridge.RemoveMoney(source, paymentType, cost) then break end
            local ok, added = pcall(Bridge.AddItem, source, entry.product.name, entry.quantity)
            if not ok or not added then
                local refunded = cost == 0 or Bridge.AddMoney(source, paymentType, cost)
                if not refunded then print(('[cloud-shop] CRITICAL refund failed for player %d, amount %d'):format(source, cost)) end
            else
                purchased = purchased + 1
                spent = spent + cost
            end
        end
        if purchased == 0 then return false, 'Nenhum produto comprado' end
        Functions.Notify.Server(source, { title = locales.notify.payment_success.shop.title, description = locales.notify.payment_success.shop.description:format(spent), type = 'success' })
        return true, ('Comprou %d produto(s) por $%d'):format(purchased, spent)
    end
    local ok, success, reason = pcall(process)
    pending[source] = nil
    if not ok then print('[cloud-shop] Erro em transação: ' .. tostring(success)); return false, 'Falha interna' end
    return success, reason
end)
AddEventHandler('playerDropped', function() pending[source] = nil end)
