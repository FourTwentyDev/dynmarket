// Global state management for the market UI
let state = {
    currentMarket: null,
    categories: new Set(),
    selectedCategory: 'all',
    translations: {},
    prices: {},
    trends: {},
    inventory: [],
    playerInventory: {},
    nextUpdate: 0,
    selectedItems: new Set(),
    inventoryLink: null,
    supplyDemandEnabled: false,
    supplyLevels: {}
};

// Utility Functions
const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 0
    }).format(value);
};

const formatTime = (ms) => {
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

const getTrendIcon = (trend) => {
    switch (trend) {
        case 'up': return '↑';
        case 'down': return '↓';
        default: return '−';
    }
};

// UI Update Functions
const updateUI = () => {
    updateCategories();
    updateItemList();
    updateTotalValue();
    updateTimer();
};

const updatePlayerInventory = () => {
    fetch(`https://${GetParentResourceName()}/getPlayerInventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    })
    .then(resp => resp.json())
    .then(inventory => {
        state.playerInventory = inventory;
        updateUI();
    })
    .catch(error => {
        console.error('Error fetching player inventory:', error);
        state.playerInventory = {};
        updateUI();
    });
};

const updateCategories = () => {
    const categoriesContainer = document.getElementById('categories');
    categoriesContainer.innerHTML = '';

    // Add "All" category button
    const allButton = document.createElement('button');
    allButton.className = `category-button ${state.selectedCategory === 'all' ? 'active' : ''}`;
    allButton.textContent = 'All';
    allButton.onclick = () => selectCategory('all');
    categoriesContainer.appendChild(allButton);

    // Add individual category buttons
    state.categories.forEach(category => {
        const button = document.createElement('button');
        button.className = `category-button ${state.selectedCategory === category ? 'active' : ''}`;
        button.textContent = category;
        button.onclick = () => selectCategory(category);
        categoriesContainer.appendChild(button);
    });
};

const updateItemList = () => {
    const itemList = document.getElementById('itemList');
    itemList.innerHTML = '';

    // Filter and display items based on selected category
    state.inventory
        .filter(item => state.selectedCategory === 'all' || item.category === state.selectedCategory)
        .forEach(item => {
            const playerItem = state.playerInventory[item.item] || { count: 0 };
            const currentPrice = state.prices[item.item] || item.basePrice;
            const trend = state.trends[item.item] || 'stable';
            const total = currentPrice * playerItem.count;

            // Create item card
            const itemElement = document.createElement('div');
            itemElement.className = 'item-card';
            itemElement.innerHTML = `
                <div class="item-info">
                    <input type="checkbox" 
                           class="item-checkbox" 
                           ${state.selectedItems.has(item.item) ? 'checked' : ''}
                           ${playerItem.count === 0 ? 'disabled' : ''}
                           data-item="${item.item}">
                    <img 
                        src="${state.inventoryLink.replace("%s", item.item)
                        }" 
                        class="item-image"
                        onerror="this.src='nui://inventory/web/dist/assets/items/default.png'"
                        alt="${item.name}"
                    >
                    <div class="item-details">
            <h3>${item.name}</h3>
            <p>${state.translations.quantity}: ${playerItem.count}x</p>
            ${state.supplyDemandEnabled ? `
                <span class="supply-indicator ${getSupplyClass(item.item)}">
                    ${getSupplyText(item.item)}
                </span>
            ` : ''}
        </div>
                </div>
                <div class="price-info">
                    <div class="price-current">
                        ${formatCurrency(currentPrice)}
                        <span class="price-trend ${trend === 'up' ? 'trend-up' : trend === 'down' ? 'trend-down' : ''}">
                            ${getTrendIcon(trend)}
                        </span>
                    </div>
                    <div class="price-total">
                        ${state.translations.total}: ${formatCurrency(total)}
                    </div>
                </div>
            `;

            // Handle item selection
            const checkbox = itemElement.querySelector('.item-checkbox');
            checkbox.addEventListener('change', (e) => {
                if (e.target.checked) {
                    state.selectedItems.add(item.item);
                } else {
                    state.selectedItems.delete(item.item);
                }
                updateTotalValue();
            });

            itemList.appendChild(itemElement);
        });
};

const getSupplyClass = (itemName) => {
    const trend = state.trends[itemName];
    if (trend === 'down') return 'supply-high';
    if (trend === 'up') return 'supply-low';
    return 'supply-normal';
};

const getSupplyText = (itemName) => {
    const trend = state.trends[itemName];
    if (trend === 'down') return state.translations.supply_high;
    if (trend === 'up') return state.translations.supply_low;
    return state.translations.supply_normal;
};

const updateTotalValue = () => {
    // Calculate total value of selected items
    const totalValue = state.inventory.reduce((sum, item) => {
        if (state.selectedItems.has(item.item)) {
            const playerItem = state.playerInventory[item.item] || { count: 0 };
            const price = state.prices[item.item] || item.basePrice;
            return sum + (price * playerItem.count);
        }
        return sum;
    }, 0);

    document.getElementById('totalValue').textContent = formatCurrency(totalValue);
    document.getElementById('sellButton').disabled = totalValue <= 0;
};

const updateTimer = () => {
    const timer = document.getElementById('nextUpdate');
    if (state.nextUpdate > 0) {
        const remaining = Math.max(0, state.nextUpdate - Date.now());
        timer.textContent = `${state.translations.next_update}: ${formatTime(remaining)}`;
    }
};

// Category Selection
const selectCategory = (category) => {
    state.selectedCategory = category;
    updateUI();
};

// UI Event Handlers
const handleShowUI = (data) => {
    state.currentMarket = data.marketData;
    state.translations = data.translations;
    state.prices = data.marketData.prices;
    state.trends = data.marketData.trends;
    state.nextUpdate = Date.now() + data.marketData.nextUpdate;
    state.inventory = data.marketData.config.items;
    state.selectedItems.clear();
    state.supplyDemandEnabled = data.supplyDemandEnabled;
    state.inventoryLink = data.inventoryLink

    state.categories = new Set(data.marketData.config.items.map(item => item.category));

    // Update UI elements
    document.getElementById('marketTitle').textContent = data.marketData.config.name;
    document.getElementById('totalValueLabel').textContent = state.translations.total_value;
    document.getElementById('sellButton').textContent = state.translations.sell_all;
    if (state.supplyDemandEnabled) {
        document.getElementById('marketInfo').textContent = state.translations.supply_demand_active;
    }
    document.body.style.display = 'block';
    updatePlayerInventory();
};

// Initialize timer update interval
setInterval(updateTimer, 1000);

// Event Listeners
document.getElementById('closeButton').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
});

document.getElementById('sellButton').addEventListener('click', () => {
    if (!state.currentMarket) return;

    const selectedInventory = state.inventory.filter(item => state.selectedItems.has(item.item));
    
    fetch(`https://${GetParentResourceName()}/sellItems`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            items: selectedInventory
        })
    });
});

// NUI Message Handler
window.addEventListener('message', (event) => {
    const { type, ...data } = event.data;

    switch (type) {
        case 'showUI':
            handleShowUI(data);
            break;
            
        case 'hideUI':
            document.body.style.display = 'none';
            state.selectedItems.clear();
            break;
            
        case 'updatePrices':
                state.prices = data.prices;
                state.trends = data.trends;
                state.supplyDemandEnabled = data.supplyDemandEnabled;
                if (data.nextUpdate) {
                    state.nextUpdate = Date.now() + data.nextUpdate;
                }
                updateUI();
                break;
            
        case 'sellComplete':
            state.selectedItems.clear();
            updatePlayerInventory();
            break;
    }
});

// Close UI on escape key
document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape') {
        document.getElementById('closeButton').click();
    }
});