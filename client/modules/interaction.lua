-- Configuration
local Functions = require("config.functions")

-- Modules
local ShopPeds = require("client.modules.shop-ped")
local checkJob = require("client.modules.job")
local checkLicense = require("client.modules.license")

---@param shopKey string
local function openShopUI(shopKey)
	Functions.ToggleHud(false)

	SetNuiFocus(true, true)
	SendNUIMessage({ action = "toggleShop", showShop = true })

	while IsScreenblurFadeRunning() do
		Wait(50)
	end
	TriggerScreenblurFadeIn(200)

	LocalPlayer.state:set("currentShop", shopKey, true)

	ShopPeds.ApplySpeech("Generic_Hi", "Speech_Params_Force")
end

---@param shopKey string
---@param shopData table
local function openShop(shopKey, shopData)
	if not shopKey or not shopData then return end

	log.verbose("[openShop]", json.encode({ "Categories:", shopData.Categories, "Items:", shopData.Items }))

    local allowed, reason = lib.callback.await('cloud-shop:authorizeShop', false, shopKey)
    if not allowed then
        if reason == 'license' then
            checkLicense(shopKey, shopData)
        else
            Functions.Notify.Client({ title = 'Acesso negado', description = reason == 'job' and 'Você não possui o emprego exigido.' or 'Aproxime-se da loja.', type = 'error' })
        end
        return
    end
    openShopUI(shopKey)
end

local function closeShopUI()
	SetNuiFocus(false, false)
	SendNUIMessage({ action = "toggleShop", showShop = false })

	while IsScreenblurFadeRunning() do
		Wait(50)
	end
	TriggerScreenblurFadeOut(200)

	Functions.ToggleHud(true)

	LocalPlayer.state:set("currentShop", nil, true)
end

local function closeShop()
	closeShopUI()
	ShopPeds.ApplySpeech("Generic_Bye", "Speech_Params_Force")
end

return {
	Open = openShop,
	OpenUI = openShopUI,
	Close = closeShop,
	CloseUI = closeShopUI,
}
