Config = {}

-- General settings
Config.Debug = false
Config.Locale = 'en'

Config.Intervals = {
    priceUpdate = 300000, 
    databaseSave = 900000  -- 15 minutes
}

Config.UI = {
    key = 38,             -- E key to open market
    command = 'market',   -- Command to open market (/market) (Admin only)
    closeKey = 177,        -- Backspace to close
    inventoryLink = "nui://inventory/web/dist/assets/items/%s.png" -- Link to your item pictures, keep %s, it gets replaced with item name
}

Config.Markets = {
    ["food_market"] = {
        enabled = true,
        name = "Lebensmittelmarkt",
        blip = {
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
            maxChangePercent = 10
        },
        items = {
            -- Restaurant Zutaten
            {
                name = "Burgerbrötchen",
                item = "ing_bread",
                basePrice = 100,
                category = "Backwaren"
            },
            {
                name = "Fleisch",
                item = "ing_meat",
                basePrice = 100,
                category = "Fleisch"
            },
            {
                name = "Salat",
                item = "ing_salad",
                basePrice = 100,
                category = "Gemüse"
            },
            {
                name = "Tomaten",
                item = "ing_tomato",
                basePrice = 100,
                category = "Gemüse"
            },
            {
                name = "Gewürzgurken",
                item = "ing_pickle",
                basePrice = 100,
                category = "Gemüse"
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
            npcModel = "s_m_m_fishmerchant"
        },
        priceSettings = {
            minMultiplier = 0.6,
            maxMultiplier = 1.8,
            maxChangePercent = 20
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
                category = "Edle Fische"
            },
            {
                name = "Thunfisch",
                item = "farm_tuna",
                basePrice = 120,
                category = "Edle Fische"
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
            maxChangePercent = 15
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
                category = "Erze"
            },
            {
                name = "Kupfererz",
                item = "farm_copper",
                basePrice = 60,
                category = "Erze"
            },
            {
                name = "Golderz",
                item = "farm_gold",
                basePrice = 180,
                category = "Edelmetalle"
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
        name = "Pfandleiher",
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
            maxChangePercent = 25
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