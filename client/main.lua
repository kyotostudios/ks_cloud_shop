if not LoadResourceFile(cache.resource, "web/dist/index.html") then error("UI has not been built! Download the release version from https://github.com/cloud-resources/cloud-shop/releases") end

-- Configuration
local Config = require("config.main")
local Functions = require("config.functions")

-- Locales
local locales = lib.loadJson(("locales.%s"):format(Config.Locale))

-- Modules
local Interaction = require("client.modules.interaction")
local ShopPeds = require("client.modules.shop-ped")
local handleTransaction = require("client.modules.transaction")
local Manager = require("client.modules.shop_manager")

--[[ Initialization ]]

LocalPlayer.state:set("currentShop", nil, true)
local RuntimeShops = Config.Shops
local activePoints, activeBlips, activeTargets = {}, {}, {}


local function getInteractDistance(shopData)
	if shopData.Interaction.HelpText.enabled then
		return shopData.Interaction.HelpText.distance
	elseif shopData.Interaction.FloatingText.enabled then
		return shopData.Interaction.FloatingText.distance
	end
	return nil
end

local function createPoints(shopKey, shopData, shopCoords)
	local shopPoint = lib.points.new({
		coords = shopCoords,
		distance = shopData.PointRadius,
		interactDistance = getInteractDistance(shopData),
		ped = nil,
	})

	activePoints[#activePoints + 1] = shopPoint

	function shopPoint:onEnter()
		if shopData.Indicator.Ped.enabled then self.ped = ShopPeds.Spawn(shopData, shopCoords) end
	end

	function shopPoint:onExit()
		if shopData.Indicator.Ped.enabled then ShopPeds.Delete(self.ped) end
	end

	function shopPoint:nearby()
		if not LocalPlayer.state["currentShop"] then
			if shopData.Indicator.Marker.enabled then
				local markerConfig = shopData.Indicator.Marker
				---@diagnostic disable-next-line: missing-parameter
				DrawMarker(markerConfig.type, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, markerConfig.size.x, markerConfig.size.y, markerConfig.size.z, markerConfig.color[1], markerConfig.color[2], markerConfig.color[3], markerConfig.color[4], markerConfig.bobUpAndDown, markerConfig.faceCamera, 2, markerConfig.rotate)
			end
		end

		if shopData.Interaction.HelpText.enabled or shopData.Interaction.FloatingText.enabled then
			if self.isClosest and self.currentDistance <= self.interactDistance then
				if IsPlayerDead(cache.playerId) or IsPedInAnyVehicle(cache.ped, false) then return end

				if not LocalPlayer.state["currentShop"] then
					if shopData.Interaction.HelpText.enabled then Functions.Interact.HelpText(locales.interaction.help_text) end
					if shopData.Interaction.FloatingText.enabled then Functions.Interact.FloatingHelpText(locales.interaction.floating_text, self.ped, self.coords) end
				end

				if IsControlJustReleased(0, shopData.Interaction.OpenKey) then Interaction.Open(shopKey, shopData) end
			end
		end
	end
end

local function resetWorld()
    for _, point in ipairs(activePoints) do point:remove() end
    for _, blip in ipairs(activeBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    if GetResourceState('ox_target') == 'started' then
        for _, zone in ipairs(activeTargets) do exports.ox_target:removeZone(zone) end
    end
    activePoints, activeBlips, activeTargets = {}, {}, {}
    ShopPeds.DeleteAll()
end
local function rebuildWorld()
    resetWorld()
    for shopKey, shopData in pairs(RuntimeShops) do
        for _, shopCoords in ipairs(shopData.Locations) do
            if shopData.Blip.enabled then activeBlips[#activeBlips + 1] = createBlip(shopCoords, shopData.Blip) end
            createPoints(shopKey, shopData, shopCoords)
            if shopData.Interaction.Target.enabled and GetResourceState('ox_target') == 'started' then
                activeTargets[#activeTargets + 1] = Functions.Interact.AddTarget(shopKey, shopData, shopCoords, Interaction.Open)
            end
        end
    end
end
local function reviveShops(shops)
    for _, shop in pairs(shops) do
        for i, coords in ipairs(shop.Locations) do
            shop.Locations[i] = vec4(coords.x, coords.y, coords.z, coords.w)
        end
        local size = shop.Indicator.Marker.size
        if type(size) == 'table' then shop.Indicator.Marker.size = vec3(size.x, size.y, size.z) end
        local box = shop.Interaction.Target.boxZoneSize
        if type(box) == 'table' then shop.Interaction.Target.boxZoneSize = vec3(box.x, box.y, box.z) end
    end
    return shops
end
CreateThread(function()
    if (Config.ShopManager or {}).enabled then
        RuntimeShops = reviveShops(lib.callback.await('cloud-shop:getShops', false) or {})
    end
    rebuildWorld()
end)
RegisterNetEvent('cloud-shop:syncShops', function(shops)
    if not (Config.ShopManager or {}).enabled or type(shops) ~= 'table' then return end
    if LocalPlayer.state.currentShop then Interaction.CloseUI() end
    RuntimeShops = reviveShops(shops)
    rebuildWorld()
end)

--[[ NUI Callbacks ]]

RegisterNUICallback("shop:callback", function(data, cb)
	local actionName = data.action
	if type(actionName) ~= "string" then return end

	if Manager.Handle(data, cb) then return end
    local shopData = RuntimeShops[LocalPlayer.state["currentShop"]]

	local handlers = {
		closeShop = function()
			local success = pcall(Interaction.Close)
			cb(success)
		end,

		payItems = function()
			log.debug(("[NUI:payItems] Payment Type: %s | Cart Array: %s"):format(data.type, json.encode(data.cart)))

			local success = handleTransaction(data.type, data.cart)
			if success then ShopPeds.ApplySpeech("Generic_Thanks", "Speech_Params_Force_Shouted_Critical") end
			cb(success)
		end,

		-- Initialization

		getCategories = function()
            if not shopData then cb({}); return end
			cb(shopData.Categories)
		end,
		getItems = function()
            if not shopData then cb({}); return end
			cb(shopData.Items)
		end,
		getLocales = function()
            if not shopData then cb(false); return end
			locales.ui.main.header = shopData.Locales.MainHeader
			locales.ui.cart.header = shopData.Locales.CartHeader
			cb({ imagePath = Config.ImagePath, soundVolume = (GetProfileSetting(300) / 10), locales = locales.ui })
		end,

		-- Sounds

		selectCategory = function()
			playSound("select")
			cb(true)
		end,
		addItem = function()
			playSound("add")
			cb(true)
		end,
		updateQuantity = function()
			playSound("quantity")
			cb(true)
		end,
		removeItem = function()
			playSound("remove")
			cb(true)
		end,
	}

	local handler = handlers[actionName]
	if handler then handler() end
end)

-- [[ Clean Up ]]

local function cleanUp()
	Interaction.CloseUI()
    resetWorld()
    Manager.Close()
end

AddEventHandler("onResourceStop", function(resource)
	if resource ~= cache.resource then return end
	cleanUp()
end)
