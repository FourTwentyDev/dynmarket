-- Initialize ESX framework
ESX = exports["es_extended"]:getSharedObject()

-- State management
local currentMarket = nil
local isNearMarket = false
local showingUI = false
local marketBlips = {}

-- Translation helper function
local function Translate(key, ...)
    if not Locales or not Locales[Config.Locale] then 
        return key 
    end

    local str = Locales[Config.Locale][key]
    if not str then
        return key
    end

    return ... and string.format(str, ...) or str
end

-- Initialize market locations and NPCs
CreateThread(function()
    -- Wait for game to fully initialize
    Wait(2000)
    
    for marketId, market in pairs(Config.Markets) do
        if market.enabled then
            -- Debug logging
            if Config.Debug then
                print("Creating market: " .. marketId)
                print("Location: " .. tostring(market.location.coords))
            end
            
            -- Ensure coordinates are valid
            if market.location and market.location.coords then
                -- Create map blip with error handling
                local blip = AddBlipForCoord(
                    market.location.coords.x,
                    market.location.coords.y,
                    market.location.coords.z
                )
                
                if blip and blip ~= 0 then -- Validate blip creation
                    SetBlipSprite(blip, market.blip.sprite or 1)
                    SetBlipDisplay(blip, market.blip.display or 4)
                    SetBlipScale(blip, market.blip.scale or 1.0)
                    SetBlipColour(blip, market.blip.color or 1)
                    SetBlipAsShortRange(blip, true)
                    
                    -- Set blip name with error handling
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString(market.name or "Market")
                    EndTextCommandSetBlipName(blip)
                    
                    -- Store blip reference
                    marketBlips[marketId] = blip
                    
                    if Config.Debug then
                        print("Successfully created blip for " .. marketId)
                    end
                else
                    print("^1ERROR: Failed to create blip for " .. marketId .. "^7")
                end
            else
                print("^1ERROR: Invalid coordinates for market " .. marketId .. "^7")
            end
            
            -- Create market NPC
            if market.location.npcModel then
                local hash = GetHashKey(market.location.npcModel)
                RequestModel(hash)
                
                -- Add timeout to model loading
                local timeout = 0
                while not HasModelLoaded(hash) and timeout < 50 do
                    Wait(100)
                    timeout = timeout + 1
                end
                
                if HasModelLoaded(hash) then
                    -- Spawn and configure NPC
                    local ped = CreatePed(4, hash, 
                        market.location.coords.x, 
                        market.location.coords.y, 
                        market.location.coords.z - 1.0, 
                        market.location.heading, 
                        false, true)
                    
                    if DoesEntityExist(ped) then
                        SetEntityHeading(ped, market.location.heading)
                        FreezeEntityPosition(ped, true)
                        SetEntityInvincible(ped, true)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        
                        -- Add additional NPC configuration
                        SetPedDiesWhenInjured(ped, false)
                        SetPedCanPlayAmbientAnims(ped, true)
                        SetPedCanRagdollFromPlayerImpact(ped, false)
                        SetPedRagdollOnCollision(ped, false)
                        SetPedConfigFlag(ped, 251, true) -- Set NPC immune to player collision
                        
                        if Config.Debug then
                            print("Successfully created NPC for " .. marketId)
                        end
                    else
                        print("^1ERROR: Failed to create NPC for " .. marketId .. "^7")
                    end
                else
                    print("^1ERROR: Failed to load NPC model for " .. marketId .. "^7")
                end
                
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end)

-- Market interaction loop
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        isNearMarket = false
        
        -- Check distance to all markets
        for marketId, market in pairs(Config.Markets) do
            if market.enabled then
                local distance = #(playerCoords - market.location.coords)
                
                if distance < 3.0 then
                    sleep = 0
                    isNearMarket = true
                    currentMarket = marketId
                    
                    -- Show interaction prompt
                    if not showingUI then
                        ESX.ShowHelpNotification(Translate('press_interact'))
                        
                        -- Handle interaction key press
                        if IsControlJustPressed(0, Config.UI.key) then
                            OpenMarketUI(marketId)
                        end
                    end
                    break
                end
            end
        end
        
        -- Auto-close UI when player walks away
        if not isNearMarket and showingUI then
            CloseMarketUI()
        end
        
        Wait(sleep)
    end
end)

-- UI Management Functions
function OpenMarketUI(marketId)
    if showingUI then return end
    
    ESX.TriggerServerCallback('fourtwenty_dynmarket:getMarketInfo', function(marketData)
        if not marketData then return end
        
        showingUI = true
        SetNuiFocus(true, true)
        
        -- Prepare and send UI data
        local uiData = {
            type = 'showUI',
            marketData = marketData,
            translations = GetTranslations(),
            inventoryLink = Config.UI.inventoryLink,
            supplyDemandEnabled = Config.IsSupplyDemandEnabled(marketId)
        }
        
        SendNUIMessage(uiData)
    end, marketId)
end

function CloseMarketUI()
    if not showingUI then return end
    
    showingUI = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideUI'
    })
end

-- Translation helper
function GetTranslations()
    local translations = {}
    local keys = {
        'market_title',
        'next_update',
        'total_value',
        'sell_all',
        'price',
        'quantity',
        'current_price',
        'trend_up',
        'trend_down',
        'trend_stable',
        'category',
        'total',
        'close',
        'supply_high',
        'supply_low',
        'supply_normal'
    }
    
    for _, key in ipairs(keys) do
        translations[key] = Translate(key)
    end
    
    return translations
end

-- Event Handlers
RegisterNetEvent('fourtwenty_dynmarket:updatePrices')
AddEventHandler('fourtwenty_dynmarket:updatePrices', function(marketId, prices, trends, nextUpdate)
    if showingUI and currentMarket == marketId then
        SendNUIMessage({
            type = 'updatePrices',
            prices = prices,
            trends = trends,
            nextUpdate = nextUpdate,
            supplyDemandEnabled = Config.IsSupplyDemandEnabled(marketId)
        })
    end
end)

RegisterNetEvent('fourtwenty_dynmarket:sellComplete')
AddEventHandler('fourtwenty_dynmarket:sellComplete', function(data)
    ESX.ShowNotification(Translate('sold_items', data.total))
    
    if showingUI then
        SendNUIMessage({
            type = 'sellComplete',
            data = data
        })
        
        -- Request inventory refresh after sale
        TriggerEvent('fourtwenty_dynmarket:refreshInventory')
    end
end)

RegisterNetEvent('fourtwenty_dynmarket:notification')
AddEventHandler('fourtwenty_dynmarket:notification', function(message)
    ESX.ShowNotification(Translate(message))
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Remove all blips when resource stops
    for _, blip in pairs(marketBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    -- Reset UI state
    if showingUI then
        SetNuiFocus(false, false)
        showingUI = false
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    CloseMarketUI()
    cb('ok')
end)

RegisterNUICallback('sellItems', function(data, cb)
    if not currentMarket then 
        cb('error')
        return
    end
    
    TriggerServerEvent('fourtwenty_dynmarket:sellItems', currentMarket, data.items)
    cb('ok')
end)

RegisterNUICallback('getPlayerInventory', function(data, cb)
    if not currentMarket then 
        cb({})
        return
    end

    if Config.ox_inventory then
        local inventory = {}
        local items = exports.ox_inventory:Items()
    
        for _, item in pairs(items) do
            if item.count and item.count > 0 then
                inventory[item.name] = {
                    count = item.count,
                    label = item.label
                }
            end
        end
        cb(inventory)
    else
        local playerData = ESX.GetPlayerData()
        local inventory = {}
        
        -- Format inventory data for UI
        if playerData and playerData.inventory then
            for _, item in ipairs(playerData.inventory) do
                if item.count and item.count > 0 then
                    inventory[item.name] = {
                        count = item.count,
                        label = item.label
                    }
                end
            end
        end
        cb(inventory)
    end
end)

-- Additional utility functions
function IsPlayerNearMarket(marketId)
    local market = Config.Markets[marketId]
    if not market or not market.enabled then return false end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - market.location.coords)
    
    return distance < 3.0
end

-- Command handler for admin market control (if enabled)
if Config.UI.command then
    RegisterCommand(Config.UI.command, function(source, args)
        if not args[1] then return end
        
        local marketId = args[1]
        if Config.Markets[marketId] and IsPlayerNearMarket(marketId) then
            OpenMarketUI(marketId)
        else
            ESX.ShowNotification(Translate('not_near_market'))
        end
    end)
end

-- Key mapping for market interaction
RegisterKeyMapping('market_interact', 'Open Market Menu', 'keyboard', 'E')
RegisterCommand('market_interact', function()
    if currentMarket and not showingUI and IsPlayerNearMarket(currentMarket) then
        OpenMarketUI(currentMarket)
    end
end, false)