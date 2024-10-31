# FourTwenty DynMarket 💹
A sophisticated and highly customizable dynamic market system with real-time price fluctuations and an intuitive NUI interface. Create unlimited custom markets for any purpose in your FiveM server.

## Unique Features 🚀

### Dynamic Price System
- **Advanced Price Fluctuations** 📈
  - Fully customizable price algorithms per market
  - Individual trend tracking for each item
  - Configurable price boundaries and volatility
  - Market-specific economic settings
  - Real-time visual trend indicators

### Flexible Market Creation
- **Unlimited Market Types** 🏪
  - Create any type of market you need
  - Fully customizable item lists and categories
  - Individual pricing rules per market
  - Custom NPC and blip configurations
  - Location-based market behaviors

### Modern NUI Interface 💻
- **Responsive Design**
  - Clean, modern dark theme
  - Dynamic category creation
  - Real-time price updates
  - Instant transaction feedback
  - Smooth animations and transitions

- **Smart Item Management**
  - Real-time inventory synchronization
  - Bulk item selection and selling
  - Smart price calculations
  - Category-based filtering
  - Dynamic stock management

### Additional Features
- **Multi-Language Support** 🌍
  - Built-in localization system
  - Easy language expansion
  - Dynamic text configuration

- **Performance Optimization** ⚡
  - Efficient price update system
  - Smart distance checks
  - Optimized database queries
  - Minimal resource usage

## Dependencies 📦
- [es_extended](https://github.com/esx-framework/esx-legacy)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation 💿

1. Clone this repository into your server's `resources` directory
```bash
cd resources
git clone https://github.com/FourTwentyDev/dynmarket
```

2. Import the included SQL file
```bash
mysql -u your_username -p your_database < dynmarket.sql
```

3. Add to your `server.cfg`
```lua
ensure fourtwenty_dynmarket
```

## Configuration Example 🔧

### Market Configuration
The configuration system allows you to create any number of custom markets with unique properties and behaviors. Each market can be fully customized with:
- Custom locations and NPCs
- Individual price algorithms
- Unique item lists and categories
- Custom blips and markers
- Specific operating rules

## Database Structure 📚

```sql
CREATE TABLE IF NOT EXISTS fourtwenty_market_prices (
    market_id VARCHAR(50),
    item_name VARCHAR(50),
    current_price INT,
    last_update TIMESTAMP,
    PRIMARY KEY (market_id, item_name)
);
```
## Support & Links 💡
1. Join our [Discord](https://discord.gg/fourtwenty)
2. Visit [FourTwenty Development](https://fourtwenty.dev)
3. Create an issue on [GitHub](https://github.com/FourTwentyDev/dynmarket)

## License 📄
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Made with 💚 by [FourTwenty Development](https://fourtwenty.dev)

### Latest Updates
- Enhanced market customization options
- Improved price fluctuation system
- Added bulk item transactions
- Enhanced UI responsiveness
- Optimized database performance
