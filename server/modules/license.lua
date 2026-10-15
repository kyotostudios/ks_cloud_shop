local Config = require('config.main')
local Functions = require('config.functions')
local Registry = require('server.lib.shop_registry')
local Access = require('server.lib.shop_access')
local locales = lib.loadJson(('locales.%s'):format(Config.Locale))
local pending = {}
local reviewSequence = 0
local function reviewPurchase(source, shopKey, license, price, account, state, reason)
    reviewSequence = reviewSequence + 1
    local id = ('%s:%s:%s:%s'):format(os.time(), source, GetGameTimer(), reviewSequence)
    SetResourceKvp('license_review:' .. id, json.encode({
        id = id, state = state, source = source, identifier = GetPlayerIdentifierByType(source, 'license'),
        name = GetPlayerName(source), shop = shopKey, licenseType = license.type,
        amount = price, account = account, reason = tostring(reason), at = os.time()
    }))
    print(('[cloud-shop] CRITICAL licença pendente de conferência: %s (%s)'):format(id, state))
    return false, 'Compra registrada para conferência: ' .. id
end
lib.callback.register('cloud-shop:buyLicense', function(source, shopKey)
    if pending[source] then return false, 'Compra em andamento' end
    pending[source] = true
    local function process()
        local allowed, shop = Access.Check(source, shopKey, true)
        if not allowed then return false, shop end
        local license = shop.Requirement.License
        if not license.required or not license.buyDialog then return false, 'Compra indisponível' end
        if Access.HasLicense(source, license) then return false, 'Licença já existente' end
        local price = license.price
        if type(price) ~= 'number' or price < 0 then return false, 'Preço de licença inválido' end
        local cash = Bridge.GetMoney(source, 'cash') or 0
        local bank = Bridge.GetMoney(source, 'bank') or 0
        local account = cash >= price and 'cash' or (bank >= price and 'bank' or nil)
        if not account and price > 0 then return false, 'Sem dinheiro' end
        account = account or 'cash'
        if license.mode == 'inventory' then
            if GetResourceState('ox_inventory') ~= 'started' or not exports.ox_inventory:CanCarryItem(source, 'shop_license', 1) then return false, 'Inventário cheio ou indisponível' end
        end
        if price > 0 then
            local charged, result = pcall(Bridge.RemoveMoney, source, account, price)
            if not charged then return reviewPurchase(source, shopKey, license, price, account, 'charge_unknown', result) end
            if not result then return false, 'Falha no pagamento' end
        end
        local issued, added = pcall(function()
            if license.mode == 'inventory' then
                return exports.ox_inventory:AddItem(source, 'shop_license', 1, { licenseType = license.type, holder = GetPlayerName(source), issuedAt = os.time(), description = license.label })
            end
            return Bridge.AddLicense(source, license.type) ~= false
        end)
        if not issued then
            -- An exception may occur after delivery; refunding an unknown outcome can duplicate value.
            return reviewPurchase(source, shopKey, license, price, account, 'delivery_unknown', added)
        end
        if not added then
            if price > 0 then
                local refunded, result = pcall(Bridge.AddMoney, source, account, price)
                if not refunded or not result then
                    return reviewPurchase(source, shopKey, license, price, account, 'refund_pending', result)
                end
            end
            return false, 'Falha ao emitir licença'
        end
        Functions.Notify.Server(source, {
            title = locales.notify.payment_success.license.title,
            description = locales.notify.payment_success.license.description:format(license.label, price), type = 'success'
        })
        return true, 'Licença adquirida'
    end
    local ok, success, reason = pcall(process)
    pending[source] = nil
    if not ok then print('[cloud-shop] Erro em compra de licença: ' .. tostring(success)); return false, 'Falha interna' end
    return success, reason
end)
AddEventHandler('playerDropped', function() pending[source] = nil end)
