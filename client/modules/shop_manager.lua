local Config = require('config.main')
local Manager = {}
local enabled = (Config.ShopManager or {}).enabled == true
function Manager.Open()
    if not enabled then return end
    if LocalPlayer.state.currentShop then require('client.modules.interaction').CloseUI() end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'toggleManager', showManager = true })
end
function Manager.Close()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'toggleManager', showManager = false })
end
if enabled then
    RegisterNetEvent('cloud-shop:openManager', Manager.Open)
end
function Manager.Handle(data, cb)
    if not enabled then return false end
    local action = data.action
    if action == 'manager:close' then Manager.Close(); cb(true); return true end
    if action == 'manager:position' then
        local pos = GetEntityCoords(cache.ped)
        cb({ x = pos.x, y = pos.y, z = pos.z, w = GetEntityHeading(cache.ped) })
        return true
    end
    if action == 'manager:data' then
        cb(lib.callback.await('cloud-shop:manager:data', false))
        return true
    end
    if action == 'manager:inventoryItems' then
        cb(lib.callback.await('cloud-shop:manager:inventoryItems', false))
        return true
    end
    if action == 'manager:save' then
        local ok, reason = lib.callback.await('cloud-shop:manager:save', false, data.key, data.shop)
        cb({ success = ok, reason = reason })
        return true
    end
    if action == 'manager:delete' then
        local ok, reason = lib.callback.await('cloud-shop:manager:delete', false, data.key)
        cb({ success = ok, reason = reason })
        return true
    end
    if action == 'manager:grantLicense' then
        local ok, reason = lib.callback.await('cloud-shop:manager:grantLicense', false, data.target, data.licenseType)
        cb({ success = ok, reason = reason })
        return true
    end
    return false
end
return Manager
