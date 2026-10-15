local Registry = require('server.lib.shop_registry')
local Access = {}
local function hasLicense(source, rule)
    if not rule or not rule.required then return true end
    if rule.mode == 'inventory' then
        if GetResourceState('ox_inventory') ~= 'started' then return false end
        local slots = exports.ox_inventory:Search(source, 'slots', 'shop_license') or {}
        for _, slot in pairs(slots) do
            if slot.metadata and slot.metadata.licenseType == rule.type then return true end
        end
        return false
    end
    return Bridge.HasLicense(source, rule.type) == true
end
function Access.HasLicense(source, rule) return hasLicense(source, rule) end
function Access.Check(source, shopKey, skipLicense)
    if type(shopKey) ~= 'string' then return false, 'invalid_shop' end
    local shop = Registry.Get(shopKey)
    if not shop then return false, 'invalid_shop' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'invalid_player' end
    local coords = GetEntityCoords(ped)
    local proximity = false
    local interactions = shop.Interaction or {}
    local dist = math.max(3, (interactions.Target and interactions.Target.distance or 0), (interactions.HelpText and interactions.HelpText.distance or 0), (interactions.FloatingText and interactions.FloatingText.distance or 0)) + 2
    for _, spot in ipairs(shop.Locations) do
        local dx, dy, dz = coords.x - spot.x, coords.y - spot.y, coords.z - spot.z
        if dx * dx + dy * dy + dz * dz <= dist * dist then proximity = true; break end
    end
    if not proximity then return false, 'too_far' end
    local jobs = shop.Requirement.Job
    if jobs.required then
        local name, grade = Bridge.GetJob(source)
        local allowed = false
        for _, job in ipairs(jobs.jobs or {}) do
            if name == job.name and (tonumber(grade) or -1) >= job.grade then allowed = true; break end
        end
        if not allowed then return false, 'job' end
    end
    if not skipLicense and not hasLicense(source, shop.Requirement.License) then return false, 'license' end
    return true, shop
end
function Access.CheckItem(source, item)
    return hasLicense(source, item.license)
end
lib.callback.register('cloud-shop:authorizeShop', function(source, shopKey)
    local allowed, result = Access.Check(source, shopKey)
    return allowed, allowed and nil or result
end)
return Access
