-- Initialize ESX framework
ESX = exports["es_extended"]:getSharedObject()

-- State management
local currentMarket = nil
local isNearMarket = false
local showingUI = false

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
    for marketId, market in pairs(Config.Markets) do
        if market.enabled then
            -- Create map blip
            local blip = AddBlipForCoord(market.location.coords)
            SetBlipSprite(blip, market.blip.sprite)
            SetBlipDisplay(blip, market.blip.display)
            SetBlipScale(blip, market.blip.scale)
            SetBlipColour(blip, market.blip.color)
            SetBlipAsShortRange(blip, true)
            
            -- Set blip name
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(market.name)
            EndTextCommandSetBlipName(blip)
            
            -- Create market NPC
            local hash = GetHashKey(market.location.npcModel)
            RequestModel(hash)
            
            while not HasModelLoaded(hash) do
                Wait(1)
            end
            
            -- Spawn and configure NPC
            local ped = CreatePed(4, hash, 
                market.location.coords.x, 
                market.location.coords.y, 
                market.location.coords.z - 1.0, 
                market.location.heading, 
                false, true)
                
            SetEntityHeading(ped, market.location.heading)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
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
        
        SendNUIMessage({
            type = 'showUI',
            marketData = marketData,
            translations = GetTranslations(),
            inventoryLink = Config.UI.inventoryLink
        })
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
        'close'
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
            nextUpdate = nextUpdate
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
    end
end)

RegisterNetEvent('fourtwenty_dynmarket:notification')
AddEventHandler('fourtwenty_dynmarket:notification', function(message)
    ESX.ShowNotification(Translate(message))
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
end)