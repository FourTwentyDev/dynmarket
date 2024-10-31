-- Initialize ESX framework
ESX = exports["es_extended"]:getSharedObject()

-- State management
local marketPrices = {}
local nextUpdates = {}
local marketTrends = {}



local function LoadMarketPrices(marketId)
    local market = Config.Markets[marketId]
    if not market then 
        print(string.format("[DynMarket] Error: Market %s not found in config", marketId))
        return 
    end
    
    MySQL.Async.fetchAll('SELECT item_name, current_price FROM fourtwenty_market_prices WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    }, function(results)
        marketPrices[marketId] = {}
        marketTrends[marketId] = {}
        
        -- Create lookup table for saved prices
        local savedPrices = {}
        for _, row in ipairs(results) do
            savedPrices[row.item_name] = row.current_price
        end
        
        -- Initialize or load prices for each item
        for _, item in ipairs(market.items) do
            if not item.item or not item.basePrice then
                print(string.format("[DynMarket] Error: Invalid item configuration in market %s", marketId))
                goto continue
            end
            
            local currentPrice = savedPrices[item.item]
            
            if currentPrice then
                marketPrices[marketId][item.item] = currentPrice
                marketTrends[marketId][item.item] = "stable"
            else
                -- Set initial price and save to database
                marketPrices[marketId][item.item] = item.basePrice
                marketTrends[marketId][item.item] = "stable"
                
                MySQL.Async.execute('INSERT INTO fourtwenty_market_prices (market_id, item_name, current_price) VALUES (@marketId, @item, @price)', {
                    ['@marketId'] = marketId,
                    ['@item'] = item.item,
                    ['@price'] = item.basePrice
                })
            end
            
            ::continue::
        end
        
        nextUpdates[marketId] = os.time() + (Config.Intervals.priceUpdate / 1000)
        
        if Config.Debug then
            print(string.format("[DynMarket] Market initialized: %s", marketId))
        end
    end)
end

-- Market initialization functions
function InitializeMarkets()
    for marketId, market in pairs(Config.Markets) do
        if market.enabled then
            LoadMarketPrices(marketId)
        end
    end
end

-- Database initialization
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_market_prices (
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            current_price INT,
            last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (market_id, item_name)
        )
    ]])
    
    InitializeMarkets()
end)



-- Price calculation functions
local function CalculateNewPrice(marketId, itemName)
    local market = Config.Markets[marketId]
    if not market or not market.priceSettings then
        return nil
    end
    
    local settings = market.priceSettings
    local item = nil
    
    -- Find item and its base price
    for _, marketItem in ipairs(market.items) do
        if marketItem.item == itemName then
            item = marketItem
            break
        end
    end
    
    if not item then return nil end
    
    local basePrice = item.basePrice
    local currentPrice = marketPrices[marketId][itemName] or basePrice
    
    -- Calculate price boundaries
    local minPrice = math.floor(basePrice * settings.minMultiplier)
    local maxPrice = math.floor(basePrice * settings.maxMultiplier)
    
    -- Calculate maximum price change
    local maxChange = math.floor(basePrice * (settings.maxChangePercent / 100))
    local change = math.random(-maxChange, maxChange)
    
    -- Calculate new price within boundaries
    local newPrice = math.max(minPrice, math.min(maxPrice, currentPrice + change))
    
    -- Set price trend
    marketTrends[marketId][itemName] = newPrice > currentPrice and "up" or (newPrice < currentPrice and "down" or "stable")
    
    return newPrice
end

local function UpdateMarketPrices(marketId)
    if not Config.Markets[marketId] or not Config.Markets[marketId].enabled then 
        return 
    end
    
    local market = Config.Markets[marketId]
    local pricesChanged = false
    
    -- Update prices for all items
    for _, configItem in ipairs(market.items) do
        local itemName = configItem.item
        local currentPrice = marketPrices[marketId][itemName] or configItem.basePrice
        
        local newPrice = CalculateNewPrice(marketId, itemName)
        
        if newPrice and newPrice ~= currentPrice then
            marketPrices[marketId][itemName] = newPrice
            pricesChanged = true
            
            -- Update database
            MySQL.Async.execute('UPDATE fourtwenty_market_prices SET current_price = @price WHERE market_id = @marketId AND item_name = @item', {
                ['@price'] = newPrice,
                ['@marketId'] = marketId,
                ['@item'] = itemName
            })
        end
    end
    
    -- Schedule next update
    nextUpdates[marketId] = os.time() + (Config.Intervals.priceUpdate / 1000)
    
    if pricesChanged then
        local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
        TriggerClientEvent('fourtwenty_dynmarket:updatePrices', -1, marketId, marketPrices[marketId], marketTrends[marketId], timeUntilUpdate)
    end
end

-- Price update thread
CreateThread(function()
    while true do
        local currentTime = os.time()
        
        for marketId, updateTime in pairs(nextUpdates) do
            if currentTime >= updateTime then
                UpdateMarketPrices(marketId)
            end
        end
        
        Wait(5000) -- Check every 5 seconds
    end
end)

-- Event Handlers
RegisterServerEvent('fourtwenty_dynmarket:requestMarketData')
AddEventHandler('fourtwenty_dynmarket:requestMarketData', function(marketId)
    local source = source
    
    if marketPrices[marketId] then
        local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
        TriggerClientEvent('fourtwenty_dynmarket:receiveMarketData', source, {
            marketId = marketId,
            prices = marketPrices[marketId],
            trends = marketTrends[marketId],
            nextUpdate = timeUntilUpdate
        })
    end
end)

RegisterServerEvent('fourtwenty_dynmarket:sellItems')
AddEventHandler('fourtwenty_dynmarket:sellItems', function(marketId, itemList)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not Config.Markets[marketId] or not Config.Markets[marketId].enabled then 
        return 
    end
    
    local totalEarnings = 0
    local soldItems = {}
    
    -- Process each item in the sale
    for _, itemData in pairs(itemList) do
        if itemData and itemData.item then
            local item = xPlayer.getInventoryItem(itemData.item)
            
            if item and item.count and item.count > 0 then
                local price = marketPrices[marketId][itemData.item] or itemData.basePrice
                if price then
                    local earnings = math.floor(item.count * price)
                    
                    table.insert(soldItems, {
                        item = itemData.item,
                        count = item.count,
                        price = price,
                        earnings = earnings
                    })
                    
                    totalEarnings = totalEarnings + earnings
                end
            end
        end
    end
    
    -- Complete the transaction
    if totalEarnings > 0 then
        xPlayer.addAccountMoney('money', totalEarnings)
        
        for _, sale in ipairs(soldItems) do
            xPlayer.removeInventoryItem(sale.item, sale.count)
        end
        
        TriggerClientEvent('fourtwenty_dynmarket:sellComplete', source, {
            total = totalEarnings,
            items = soldItems
        })
        
        if Config.Debug then
            print(string.format("[DynMarket] Sale completed for %s: $%d", xPlayer.identifier, totalEarnings))
        end
    else
        TriggerClientEvent('fourtwenty_dynmarket:notification', source, 'no_items')
    end
end)

-- ESX Callbacks
ESX.RegisterServerCallback('fourtwenty_dynmarket:getMarketInfo', function(source, cb, marketId)
    -- Validate market exists and is enabled
    if not Config.Markets[marketId] or not Config.Markets[marketId].enabled then
        cb(false)
        return
    end
    
    -- Validate market has been initialized
    if not nextUpdates[marketId] then
        cb(false)
        return
    end
    
    -- Calculate time until next price update
    local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
    
    -- Return market data
    cb({
        config = Config.Markets[marketId],
        prices = marketPrices[marketId] or {},
        trends = marketTrends[marketId] or {},
        nextUpdate = timeUntilUpdate
    })
end)