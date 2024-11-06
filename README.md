# FourTwenty DynMarket 💹
A sophisticated and highly customizable dynamic market system with real-time price fluctuations, supply & demand mechanics, and an intuitive NUI interface. Create unlimited custom markets with advanced economic features for your FiveM server.

## Configuration Tutorial
[Click Me](configuration.md)  

## Unique Features 🚀

### Advanced Economic System
- **Dynamic Supply & Demand** 📊
  - Real-time price adjustments based on player activity
  - Automatic price recovery system
  - Configurable impact rates and recovery speeds
  - Market-specific economic rules
  - Anti-exploitation mechanisms

- **NEW: Counter-Item System** 🆕
  ```lua
  -- Example: Burger ingredients increase in price when burgers are sold
  {
      name = "Burger Bun",
      item = "ing_bread",
      basePrice = 100,
      counterItem = "burger",     -- Optional: Define a counter item
      counterEffect = 0.05        -- 5% price increase per counter item sold
  }
  ```
  - Create economic dependencies between items
  - Simulate real market behaviors
  - Optional per-item configuration
  - Automatic effect decay over time
  - Configurable impact strengths

### Dynamic Price System
- **Advanced Price Fluctuations** 📈
  - Multiple price influence factors:
    - Base random fluctuations
    - Supply & Demand impact
    - Counter-item effects
    - Time-based recovery
  - Individual trend tracking
  - Configurable boundaries and volatility
  - Real-time price calculations

### Market Creation System
- **Unlimited Market Types** 🏪
  ```lua
  ["fish_market"] = {
      enabled = true,
      name = "Fish Market",
      priceSettings = {
          minMultiplier = 0.6,
          maxMultiplier = 1.8,
          maxChangePercent = 20,
          supplyDemand = {
              enabled = true,
              impact = {
                  sale = 0.02,        -- 2% price decrease per sale
                  recovery = 0.01,     -- 1% recovery when not sold
                  maximum = 0.40       -- Maximum 40% impact
              }
          }
      }
  }
  ```
  - Fully customizable market configurations
  - Individual economic settings per market
  - Category-based organization
  - Custom NPC and blip systems
  - Location-based behaviors

### Modern NUI Interface 💻
- **Responsive Design**
  - Clean, modern dark theme
  - Real-time updates for:
    - Prices
    - Supply levels
    - Market trends
  - Dynamic category filtering
  - Smooth animations

- **Smart Item Management**
  - Real-time inventory sync
  - Bulk transactions
  - Visual trend indicators
  - Category management
  - Price history tracking

## Technical Details 🔧

### Database Structure
```sql
-- Main price tracking table
CREATE TABLE IF NOT EXISTS fourtwenty_market_prices (
    market_id VARCHAR(50),
    item_name VARCHAR(50),
    current_price INT,
    supply_impact FLOAT DEFAULT 0.0,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (market_id, item_name)
);

-- Supply/demand tracking
CREATE TABLE IF NOT EXISTS fourtwenty_market_sales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    market_id VARCHAR(50),
    item_name VARCHAR(50),
    quantity INT,
    price_per_unit INT,
    sale_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_market_item (market_id, item_name),
    INDEX idx_sale_time (sale_time)
);

-- Counter-item tracking
CREATE TABLE IF NOT EXISTS fourtwenty_counter_items (
    market_id VARCHAR(50),
    item_name VARCHAR(50),
    counter_item VARCHAR(50),
    counter_quantity INT DEFAULT 0,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (market_id, item_name, counter_item)
);
```

### Price Calculation System
```lua
-- Simplified example of price calculation
Final Price = Base Price × (1 + Random Fluctuation) × (1 - Supply Impact + Counter Effect)

Where:
- Random Fluctuation: Configured per market (maxChangePercent)
- Supply Impact: Based on recent sales
- Counter Effect: Based on counter-item sales
```

## Dependencies 📦
- [es_extended](https://github.com/esx-framework/esx-legacy)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation 💿

1. Clone the repository
```bash
cd resources
git clone https://github.com/FourTwentyDev/dynmarket
```

2. Import SQL schemas
```bash
mysql -u your_username -p your_database < dynmarket.sql
```

3. Add to server.cfg
```lua
ensure fourtwenty_dynmarket
```

4. Configure markets in config.lua
```lua
-- Example configuration included in config.lua
```

## Performance Optimization ⚡
- Resource usage: 0.0ms idle
- Active usage: 0.01-0.02ms
- Optimized through:
  - Smart distance checks
  - Efficient database queries
  - Event batching
  - Cached calculations
  - Memory management

## Support & Links 💡
1. Join our [Discord](https://discord.gg/fourtwenty)
2. Visit [FourTwenty Development](https://fourtwenty.dev)
3. Create an issue on [GitHub](https://github.com/FourTwentyDev/dynmarket)

## License 📄
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Made with 💚 by [FourTwenty Development](https://fourtwenty.dev)

### Latest Updates (v1.2.0)
- Added advanced Supply & Demand system
- Implemented Counter-Item feature for economic dependencies
- Enhanced price calculation algorithms
- Improved database structure and performance
- Added new configuration options
- Updated documentation with new features
- Optimized resource usage
