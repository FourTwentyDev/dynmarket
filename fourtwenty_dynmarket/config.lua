Config = {}
-- frameworks
Config.Framework = "ESX" -- Set to "ESX" or "QBCore" to select the framework
-- General settings
Config.Debug = false
Config.Locale = 'en'
-- Using OX Inventory?
Config.ox_inventory = false -- Set true if you use ox_inventory

-- Market update intervals (in milliseconds)
Config.Intervals = {
    randomUpdate = 1800000,    -- 30 minutes - Base interval for price updates
    minSaleDelay = 300000      -- 5 minutes - Minimum time between supply/demand updates
}

Config.UI = {
    key = 38,             -- E key to open market
    command = 'market',   -- Command to open market (/market) (Admin only)
    closeKey = 177,       -- Backspace to close
    inventoryLink = "nui://inventory/web/dist/assets/items/%s.png"
}

Config.PriceCalculation = {
    influences = {
        randomFluctuation = {
            enabled = true,     -- Enable/disable random price changes
            weight = 0.3       -- Weight for random price changes (30%)
        },
        supplyDemand = {
            enabled = true,     -- Enable/disable supply/demand influence
            weight = 0.7       -- Weight for supply/demand (70%)
        },
        counterItems = {
            enabled = true      -- Enable/disable counter items influence
        }
    },
    minChangeThreshold = 1     -- Minimum price difference to register changes 
}

Config.Markets = {
    ["food_market"] = {
        enabled = true,
        name = "Lebensmittelmarkt",
        blip = {
            state = false,
            sprite = 52,
            color = 2,
            scale = 0.8,
            display = 4
        },
        location = {
            coords = vector3(24.5, -1346.6, 29.5),
            heading = 266.0,
            npcModel = "s_m_m_linecook"
        },
        priceSettings = {
            minMultiplier = 0.7,
            maxMultiplier = 1.3,
            maxChangePercent = 10,
            supplyDemand = {
                enabled = true,
                impact = {
                    sale = 0.01,
                    recovery = 0.005,
                    maximum = 0.30
                },
                history = {
                    duration = 12,
                    resetOnRestart = false
                }
            }
        },
        items = {
            {
                name = "water",
                item = "water",
                basePrice = 100,
                category = "water",
                counterItem = "water",  -- Optional: Counter-Item
                counterEffect = 0.05     -- Optional: Counter-Item effect
            }
        }
    },

    ["fish_market"] = {
        enabled = true,
        name = "Fischmarkt",
        blip = {
            sprite = 356,
            color = 59,
            scale = 0.8,
            display = 4
        },
        location = {
            coords = vector3(-1816.5, -1193.8, 14.3),
            heading = 319.0,
            npcModel = "s_m_m_linecook"
        },
        priceSettings = {
            minMultiplier = 0.6,
            maxMultiplier = 1.8,
            maxChangePercent = 20,
            supplyDemand = {
                enabled = true,
                impact = {
                    sale = 0.02,
                    recovery = 0.01,
                    maximum = 0.40
                },
                history = {
                    duration = 24,
                    resetOnRestart = false
                }
            }
        },
        items = {
            {
                name = "Sardine",
                item = "farm_anchovy",
                basePrice = 40,
                category = "Kleinfische"
            },
            {
                name = "Forelle",
                item = "farm_trout",
                basePrice = 65,
                category = "Flussfische"
            },
            {
                name = "Lachs",
                item = "farm_salmon",
                basePrice = 85,
                category = "Edle Fische",
                counterItem = "sushi",
                counterEffect = 0.04
            },
            {
                name = "Thunfisch",
                item = "farm_tuna",
                basePrice = 120,
                category = "Edle Fische",
                counterItem = "sushi",
                counterEffect = 0.05
            },
            {
                name = "Hummer",
                item = "farm_lobster",
                basePrice = 150,
                category = "Krustentiere"
            },
            {
                name = "Krabbe",
                item = "farm_crab",
                basePrice = 90,
                category = "Krustentiere"
            },
            {
                name = "Muschel",
                item = "farm_shell",
                basePrice = 45,
                category = "Meeresfrüchte"
            }
        }
    },

    ["mining_buyer"] = {
        enabled = true,
        name = "Rohstoffhändler",
        blip = {
            sprite = 618,
            color = 46,
            scale = 0.8,
            display = 4
        },
        location = {
            coords = vector3(2964.1, 2752.8, 43.2),
            heading = 274.0,
            npcModel = "s_m_y_construct_01"
        },
        priceSettings = {
            minMultiplier = 0.7,
            maxMultiplier = 1.6,
            maxChangePercent = 15,
            supplyDemand = {
                enabled = true,
                impact = {
                    sale = 0.015,
                    recovery = 0.008,
                    maximum = 0.35
                },
                history = {
                    duration = 18,
                    resetOnRestart = false
                }
            }
        },
        items = {
            {
                name = "Kohle",
                item = "farm_coal",
                basePrice = 30,
                category = "Mineralien"
            },
            {
                name = "Eisenerz",
                item = "farm_iron",
                basePrice = 45,
                category = "Erze",
                counterItem = "iron_ingot",
                counterEffect = 0.03
            },
            {
                name = "Kupfererz",
                item = "farm_copper",
                basePrice = 60,
                category = "Erze",
                counterItem = "copper_ingot",
                counterEffect = 0.03
            },
            {
                name = "Golderz",
                item = "farm_gold",
                basePrice = 180,
                category = "Edelmetalle",
                counterItem = "gold_ingot",
                counterEffect = 0.04
            },
            {
                name = "Diamant",
                item = "farm_diamonds",
                basePrice = 350,
                category = "Edelsteine"
            },
            {
                name = "Metall",
                item = "farm_metal",
                basePrice = 40,
                category = "Materialien"
            }
        }
    },

    ["pawnshop"] = {
        enabled = true,
        name = "Pawnshop",
        blip = {
            sprite = 267,
            color = 5,
            scale = 0.8,
            display = 4
        },
        location = {
            coords = vector3(182.7, -1319.5, 29.3),
            heading = 240.0,
            npcModel = "s_m_m_cntrybar_01"
        },
        priceSettings = {
            minMultiplier = 0.5,
            maxMultiplier = 1.4,
            maxChangePercent = 25,
            supplyDemand = {
                enabled = true,
                impact = {
                    sale = 0.025,
                    recovery = 0.012,
                    maximum = 0.45
                },
                history = {
                    duration = 24,
                    resetOnRestart = false
                }
            }
        },
        items = {
            {
                name = "Eisenbarren",
                item = "farm_iron_ingot",
                basePrice = 90,
                category = "Metalle"
            },
            {
                name = "Kupferbarren",
                item = "farm_copper_ingot",
                basePrice = 120,
                category = "Metalle"
            },
            {
                name = "Goldbarren",
                item = "farm_gold_ingot",
                basePrice = 360,
                category = "Edelmetalle"
            },
            {
                name = "Perle",
                item = "farm_pearl",
                basePrice = 120,
                category = "Schmuck"
            }
        }
    }
}

-- Helper functions
function Config.GetMarketSettings(marketId)
    return Config.Markets[marketId]
end

function Config.IsSupplyDemandEnabled(marketId)
    return Config.PriceCalculation.influences.supplyDemand.enabled and
           Config.Markets[marketId] and 
           Config.Markets[marketId].priceSettings and 
           Config.Markets[marketId].priceSettings.supplyDemand and 
           Config.Markets[marketId].priceSettings.supplyDemand.enabled
end

function Config.GetSupplyDemandSettings(marketId)
    local market = Config.Markets[marketId]
    if not market or not market.priceSettings then return nil end
    return market.priceSettings.supplyDemand
end

function Config.HasCounterItem(marketId, itemName)
    if not Config.PriceCalculation.influences.counterItems.enabled then
        return false
    end
    
    local market = Config.Markets[marketId]
    if not market then return false end
    
    for _, item in ipairs(market.items) do
        if item.item == itemName then
            return item.counterItem ~= nil
        end
    end
    return false
end
