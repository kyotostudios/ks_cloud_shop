local Config = require('config.main')
local Registry = require('server.lib.shop_registry')
if not Registry.Enabled() then return end
local ace = (Config.ShopManager or {}).ace or 'cloud_shop.admin'
local command = (Config.ShopManager or {}).command or 'shopmanager'
local function permitted(source) return source > 0 and IsPlayerAceAllowed(source, ace) end
RegisterCommand(command, function(source)
    if not permitted(source) then return end
    if not Registry.Ready() then return end
    TriggerClientEvent('cloud-shop:openManager', source)
end, false)
lib.callback.register('cloud-shop:getShops', function(source)
    return Registry.All()
end)
lib.callback.register('cloud-shop:manager:data', function(source)
    if not permitted(source) then return nil end
    return { shops = Registry.All(), template = Registry.Template() }
end)
lib.callback.register('cloud-shop:manager:save', function(source, key, data)
    if not permitted(source) then return false, 'Sem permissão' end
    return Registry.Save(key, data)
end)
lib.callback.register('cloud-shop:manager:delete', function(source, key)
    if not permitted(source) then return false, 'Sem permissão' end
    return Registry.Delete(key)
end)
lib.callback.register('cloud-shop:manager:grantLicense', function(source, target, licenseType)
    if not permitted(source) then return false, 'Sem permissão' end
    target = tonumber(target)
    if not target or not GetPlayerName(target) or type(licenseType) ~= 'string' or not licenseType:match('^[%w_%-]+$') or #licenseType > 64 then return false, 'Dados inválidos' end
    if GetResourceState('ox_inventory') ~= 'started' then return false, 'ox_inventory não está ativo' end
    local metadata = { licenseType = licenseType, holder = GetPlayerName(target), issuedAt = os.time(), description = 'Licença: ' .. licenseType }
    local success = exports.ox_inventory:AddItem(target, 'shop_license', 1, metadata)
    return success == true, success and 'Licença emitida' or 'Inventário indisponível'
end)
