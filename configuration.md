### **FourTwenty Dynamic Market Configuration Guide**

This guide provides a comprehensive explanation of the configuration system, including how to use and understand the **Supply & Demand** and **Counter Item** mechanics. Use this as a reference when setting up your markets.

---

### **General Configuration**

#### **`Config.Framework`**
- Specifies the framework being used.
  - **Options:** `"ESX"` or `"QBCore"`
  - Example:  
    ```lua
    Config.Framework = "ESX"
    ```

#### **`Config.Debug`**
- Enables or disables debug output in the server console.
  - **Options:** `true` or `false`

#### **`Config.Locale`**
- Language setting for in-game text.
  - Example:  
    ```lua
    Config.Locale = 'en'
    ```

#### **`Config.ox_inventory`**
- Set to `true` if you're using OX Inventory.

---

### **UI Configuration**

#### **`Config.UI`**
Controls the user interface for interacting with markets.

- **`key`**  
  Default key to open the market (default: `E`).
  
- **`command`**  
  Admin-only command to open the market.

- **`inventoryLink`**  
  URL format for linking item images.

Example:
```lua
Config.UI = {
    key = 38,              -- Default: E key
    command = 'market',    -- Command to open market (/market)
    inventoryLink = "nui://inventory/web/dist/assets/items/%s.png"
}
```

---

### **Market-Specific Configuration**

Each market is defined in `Config.Markets`.

#### **Example Market Configuration**
```lua
Config.Markets = {
    ["pawnshop"] = {
        enabled = true,
        name = "Pawnshop",
        blip = {
            sprite = 267,
            color = 5,
            scale = 0.8,
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
                name = "Iron Ingot",
                item = "farm_iron_ingot",
                basePrice = 90,
                category = "Metals"
            }
        }
    }
}
```

---

### **Supply & Demand System**

#### **Overview**

The Supply & Demand system dynamically adjusts item prices based on recent sales and unsold periods.

#### **Configuration Fields**

- **`enabled`**  
  Toggles the supply/demand system for the market.
  - **Options:** `true` or `false`

- **`impact.sale`**  
  Price decrease as a percentage of base price per item sold.
  - Example: `0.02` = 2% price reduction per sale.

- **`impact.recovery`**  
  Price recovery as a percentage of base price for each hour without sales.
  - Example: `0.01` = 1% price recovery per hour.

- **`impact.maximum`**  
  Maximum impact from supply/demand as a percentage of base price.
  - Example: `0.30` = ±30% limit.

- **`history.duration`**  
  The number of past hours to consider for sales data.
  - Example: `24` = last 24 hours of sales.

- **`history.resetOnRestart`**  
  Resets supply/demand history on server restart.
  - **Options:** `true` or `false`

---

### **Counter Items**

Counter items influence the market by moderating the effects of Supply & Demand. They allow you to stabilize prices for critical goods.

#### **How It Works**
- **Sales of counter items reduce negative supply impact.**  
  This stabilizes the price for related items, creating a feedback loop.
  
- **Example:**  
  Selling sushi (counter item) reduces the price impact of salmon.

#### **Configuration Fields**

- **`counterItem`**  
  Specifies the counter item related to the main item.
  
- **`counterEffect`**  
  Percentage reduction in negative supply impact when counter items are sold.
  - Example: `0.05` = 5% reduction in negative supply impact.

#### **Example Item with Counter Item**
```lua
{
    name = "Salmon",
    item = "farm_salmon",
    basePrice = 85,
    category = "Edible Fish",
    counterItem = "sushi",       -- Sushi stabilizes salmon price
    counterEffect = 0.05         -- 5% impact reduction per sushi sold
}
```

---

### **Price Calculation Configuration**

`Config.PriceCalculation` defines the weights and thresholds for price changes.

- **`randomWeight`**  
  Weight for random fluctuations in price.
  - Example: `0.3` = 30% influence from random fluctuations.

- **`supplyWeight`**  
  Weight for supply/demand influences.
  - Example: `0.7` = 70% influence from supply/demand.

- **`minChangeThreshold`**  
  Minimum price difference for price changes to take effect.
  - Example: `1` = Minimum $1 difference required.

---

### **Blip Configuration**

Blips mark market locations on the map.

```lua
blip = {
    sprite = 267,
    color = 5,
    scale = 0.8,
    display = 4
}
```

- **`sprite`**  
  Icon for the blip.

- **`color`**  
  Blip color.

- **`scale`**  
  Size of the blip on the map.

- **`display`**  
  Display type (default: `4`).

---

### **Conclusion**

This configuration system allows you to create dynamic, player-driven economies. By enabling Supply & Demand and using Counter Items, you can simulate realistic market fluctuations while ensuring critical goods remain accessible.

--- 

**Need Help?**  
Feel free to join our [Discord](https://discord.gg/fourtwenty).
