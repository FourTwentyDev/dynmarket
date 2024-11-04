-- Initialize ESX framework
ESX = exports["es_extended"]:getSharedObject()

-- State management
local marketPrices = {}
local nextUpdates = {}
local marketTrends = {}
local lastSaleUpdates = {}

-- Market initialization functions
local function LoadMarketPrices(marketId)
    local market = Config.Markets[marketId]
    if not market then 
        print(string.format("[DynMarket] Error: Market %s not found in config", marketId))
        return 
    end
    
    MySQL.Async.fetchAll('SELECT item_name, current_price, supply_impact FROM fourtwenty_market_prices WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    }, function(results)
        marketPrices[marketId] = {}
        marketTrends[marketId] = {}
        lastSaleUpdates[marketId] = {}
        
        -- Create lookup table for saved prices
        local savedPrices = {}
        for _, row in ipairs(results) do
            savedPrices[row.item_name] = {
                price = row.current_price,
                supplyImpact = row.supply_impact or 0.0
            }
        end
        
        -- Initialize or load prices for each item
        for _, item in ipairs(market.items) do
            if not item.item or not item.basePrice then
                print(string.format("[DynMarket] Error: Invalid item configuration in market %s", marketId))
                goto continue
            end
            
            local saved = savedPrices[item.item]
            
            if saved then
                marketPrices[marketId][item.item] = saved.price
                marketTrends[marketId][item.item] = "stable"
            else
                marketPrices[marketId][item.item] = item.basePrice
                marketTrends[marketId][item.item] = "stable"
                
                MySQL.Async.execute('INSERT INTO fourtwenty_market_prices (market_id, item_name, current_price) VALUES (@marketId, @item, @price)', {
                    ['@marketId'] = marketId,
                    ['@item'] = item.item,
                    ['@price'] = item.basePrice
                })
            end
            
            lastSaleUpdates[marketId][item.item] = 0
            
            ::continue::
        end
        
        nextUpdates[marketId] = os.time() + (Config.Intervals.randomUpdate / 1000)
        
        if Config.Debug then
            print(string.format("[DynMarket] Market initialized: %s", marketId))
        end
    end)
end

function InitializeMarkets()
    for marketId, market in pairs(Config.Markets) do
        if market.enabled then
            LoadMarketPrices(marketId)
        end
    end
end

-- Database initialization
MySQL.ready(function()
    -- Original price table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_market_prices (
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            current_price INT,
            supply_impact FLOAT DEFAULT 0.0,
            last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (market_id, item_name)
        )
    ]])
    
    -- Supply/demand sales tracking table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_market_sales (
            id INT AUTO_INCREMENT PRIMARY KEY,
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            quantity INT,
            price_per_unit INT,
            sale_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_market_item (market_id, item_name),
            INDEX idx_sale_time (sale_time)
        )
    ]])
    
    -- Counter items tracking table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_counter_items (
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            counter_item VARCHAR(50),
            counter_quantity INT DEFAULT 0,
            last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (market_id, item_name, counter_item)
        )
    ]])
    
    -- Initialize markets after database is ready
    InitializeMarkets()
end)

-- Supply & Demand Functions
local function GetBaseSupplyImpact(marketId, itemName)
    if not Config.IsSupplyDemandEnabled(marketId) then return 0.0 end
    
    local sdSettings = Config.GetSupplyDemandSettings(marketId)
    if not sdSettings then return 0.0 end
    
    -- Get recent sales history
    local history = MySQL.Sync.fetchAll([[
        SELECT 
            COUNT(*) as transactions,
            SUM(quantity) as total_sold,
            MAX(sale_time) as last_sale
        FROM fourtwenty_market_sales
        WHERE 
            market_id = @marketId 
            AND item_name = @itemName
            AND sale_time > DATE_SUB(NOW(), INTERVAL @hours HOUR)
    ]], {
        ['@marketId'] = marketId,
        ['@itemName'] = itemName,
        ['@hours'] = sdSettings.history.duration
    })[1]

    if not history.total_sold or history.total_sold == 0 then
        return -sdSettings.impact.recovery
    end

    return math.min(
        history.total_sold * sdSettings.impact.sale,
        sdSettings.impact.maximum
    )
end

local function GetCounterItemEffect(marketId, itemName)
    local market = Config.Markets[marketId]
    if not market then return 0.0 end
    
    -- Find item configuration
    local itemConfig = nil
    for _, item in ipairs(market.items) do
        if item.item == itemName then
            itemConfig = item
            break
        end
    end
    
    -- If no counter item defined, return 0 effect
    if not itemConfig or not itemConfig.counterItem then 
        return 0.0 
    end
    
    -- Get counter item sales data
    local counterData = MySQL.Sync.fetchAll([[
        SELECT counter_quantity 
        FROM fourtwenty_counter_items 
        WHERE market_id = @marketId 
        AND item_name = @itemName 
        AND counter_item = @counterItem
        AND last_update > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ]], {
        ['@marketId'] = marketId,
        ['@itemName'] = itemName,
        ['@counterItem'] = itemConfig.counterItem
    })[1]
    
    if not counterData or not counterData.counter_quantity then 
        return 0.0 
    end
    
    -- Calculate positive effect based on counter item sales
    local effect = counterData.counter_quantity * (itemConfig.counterEffect or 0.01)
    
    -- Ensure effect doesn't exceed maximum impact
    if market.priceSettings and market.priceSettings.supplyDemand then
        return math.min(effect, market.priceSettings.supplyDemand.impact.maximum)
    end
    
    return effect
end

local function GetSupplyImpact(marketId, itemName)
    if not Config.IsSupplyDemandEnabled(marketId) then return 0.0 end
    
    local sdSettings = Config.GetSupplyDemandSettings(marketId)
    if not sdSettings then return 0.0 end
    
    -- Get base supply/demand impact
    local baseImpact = GetBaseSupplyImpact(marketId, itemName)
    
    -- Get counter item effect (if any)
    local counterEffect = GetCounterItemEffect(marketId, itemName)
    
    -- Combine effects (counter items reduce negative supply impact)
    local finalImpact = baseImpact - counterEffect
    
    -- Ensure within maximum bounds
    return math.max(-sdSettings.impact.maximum, finalImpact)
end

local function CalculateNewPrice(marketId, itemName)
    if Config.Debug then
        print("\n=== Starting price calculation for " .. itemName .. " in market " .. marketId .. " ===")
    end
    
    local market = Config.Markets[marketId]
    if not market or not market.priceSettings then
        print("Error: Invalid market or missing price settings")
        return nil
    end
    
    -- Find item and its base price
    local item = nil
    for _, marketItem in ipairs(market.items) do
        if marketItem.item == itemName then
            item = marketItem
            break
        end
    end
    if not item then 
        print("Error: Item not found in market")
        return nil 
    end
    
    local basePrice = item.basePrice
    local currentPrice = marketPrices[marketId][itemName] or basePrice
    
    if Config.Debug then
        print("Base price: " .. basePrice)
        print("Current price: " .. currentPrice)
    end
    
    -- Calculate random fluctuation
    local maxChange = math.floor(basePrice * (market.priceSettings.maxChangePercent / 100))
    local randomChange = math.random(-maxChange, maxChange)
    local newPrice = currentPrice + randomChange
    
    if Config.Debug then
        print("Random price change: " .. randomChange)
        print("New price after random change: " .. newPrice)
    end
    
    -- Apply supply & demand if enabled
    if Config.IsSupplyDemandEnabled(marketId) then
        local lastSaleTime = lastSaleUpdates[marketId][itemName] or 0
        local timeSinceLastSale = os.time() - lastSaleTime
        
        if Config.Debug then
            print("\nSupply & Demand is enabled")
            print("Time since last sale: " .. timeSinceLastSale .. " seconds")
        end
        
        if timeSinceLastSale >= (Config.Intervals.minSaleDelay / 1000) then
            local supplyImpact = GetSupplyImpact(marketId, itemName)
            newPrice = newPrice * (1 - supplyImpact)
            
            if Config.Debug then
                print("Supply impact factor: " .. supplyImpact)
                print("Price after supply impact: " .. newPrice)
            end
        elseif Config.Debug then
            print("Too soon since last sale, skipping supply impact")
        end
    elseif Config.Debug then
        print("\nSupply & Demand is disabled")
    end
    
    -- Ensure price stays within boundaries
    local minPrice = math.floor(basePrice * market.priceSettings.minMultiplier)
    local maxPrice = math.floor(basePrice * market.priceSettings.maxMultiplier)
    local finalPrice = math.max(minPrice, math.min(maxPrice, math.floor(newPrice)))
    
    if Config.Debug then
        print("\nPrice boundaries:")
        print("Min allowed price: " .. minPrice)
        print("Max allowed price: " .. maxPrice)
        print("Final adjusted price: " .. finalPrice)
    end
    
    -- Set price trend
    local trend = finalPrice > currentPrice and "up" or (finalPrice < currentPrice and "down" or "stable")
    marketTrends[marketId][itemName] = trend
    
    if Config.Debug then
        print("Price trend: " .. trend)
        print("=== Price calculation complete ===\n")
    end
    
    return finalPrice
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
    nextUpdates[marketId] = os.time() + (Config.Intervals.randomUpdate / 1000)
    
    -- Notify clients if prices changed
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

-- Counter items update thread
CreateThread(function()
    while true do
        Wait(3600000) -- Check every hour
        
        -- Reduce counter item quantities by 50% if they haven't been updated in 24 hours
        MySQL.Async.execute([[
            UPDATE fourtwenty_counter_items 
            SET counter_quantity = FLOOR(counter_quantity * 0.5)
            WHERE last_update < DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ]])
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
                    
                    -- Track sale for supply/demand if enabled
                    if Config.IsSupplyDemandEnabled(marketId) then
                        lastSaleUpdates[marketId][itemData.item] = os.time()
                        
                        MySQL.Async.execute([[
                            INSERT INTO fourtwenty_market_sales 
                                (market_id, item_name, quantity, price_per_unit)
                            VALUES 
                                (@marketId, @item, @quantity, @price)
                        ]], {
                            ['@marketId'] = marketId,
                            ['@item'] = itemData.item,
                            ['@quantity'] = item.count,
                            ['@price'] = price
                        })
                    end
                end
            end
        end
    end
    
    -- Complete transaction if items were sold
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

-- Counter item sale event
RegisterServerEvent('fourtwenty_dynmarket:counterItemSold')
AddEventHandler('fourtwenty_dynmarket:counterItemSold', function(marketId, itemName, counterItem, quantity)
    if not Config.Markets[marketId] then return end
    
    -- Validate that this counter item exists in configuration
    local isValidCounter = false
    for _, item in ipairs(Config.Markets[marketId].items) do
        if item.item == itemName and item.counterItem == counterItem then
            isValidCounter = true
            break
        end
    end
    
    if not isValidCounter then return end
    
    -- Update counter item quantity
    MySQL.Async.execute([[
        INSERT INTO fourtwenty_counter_items 
            (market_id, item_name, counter_item, counter_quantity) 
        VALUES 
            (@marketId, @itemName, @counterItem, @quantity)
        ON DUPLICATE KEY UPDATE 
            counter_quantity = counter_quantity + @quantity,
            last_update = CURRENT_TIMESTAMP
    ]], {
        ['@marketId'] = marketId,
        ['@itemName'] = itemName,
        ['@counterItem'] = counterItem,
        ['@quantity'] = quantity
    })
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

-- Additional helper functions
local function ResetSupplyDemand(marketId)
    if not Config.Markets[marketId] then return end
    
    MySQL.Async.execute('DELETE FROM fourtwenty_market_sales WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    })
    
    MySQL.Async.execute('UPDATE fourtwenty_market_prices SET supply_impact = 0.0 WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    })
end

-- Export functions for other resources
exports('getItemPrice', function(marketId, itemName)
    if marketPrices[marketId] and marketPrices[marketId][itemName] then
        return marketPrices[marketId][itemName]
    end
    return nil
end)

exports('getMarketTrends', function(marketId)
    return marketTrends[marketId] or {}
end)

exports('resetMarketPrices', function(marketId)
    if Config.Markets[marketId] then
        LoadMarketPrices(marketId)
        return true
    end
    return false
end)