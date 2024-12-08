let menuStructure = [];
let currentCategory = '';
let allItems = [];

window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.type === "openMenu") {
        document.getElementById('main-panel').style.display = 'block';
        menuStructure = data.menuStructure;
        loadCategories(menuStructure);
        initializeSearch();
    } else if (data.type === "closeMenu") {
        document.getElementById('main-panel').style.display = 'none';
    }
});

function loadCategories(menuStructure) {
    const categoriesContainer = document.getElementById('categories-container');
    categoriesContainer.innerHTML = '';
    menuStructure.forEach(category => {
        let categoryElement = document.createElement('div');
        categoryElement.className = 'category-item';
        let iconClass = getCategoryIcon(category.label);
        categoryElement.innerHTML = `<i class="${iconClass}"></i> ${category.label}`;
        categoryElement.addEventListener('click', () => showItems(category));
        categoriesContainer.appendChild(categoryElement);
    });
    document.getElementById('categories-container').classList.remove('hidden');
    document.getElementById('items-container').classList.add('hidden');
    document.getElementById('back-button').classList.add('hidden');
    document.getElementById('sell-items').classList.add('hidden');
    document.getElementById('buy-items').classList.add('hidden');
}

function adjustItemsContainerWidth() {
    const itemsContainer = document.getElementById('items-container');
    const itemCount = itemsContainer.children.length;
    const itemWidth = 115; // 100px width + 15px gap
    const maxItemsPerRow = Math.floor((itemsContainer.offsetWidth + 15) / itemWidth);
    const optimalWidth = Math.min(itemCount, maxItemsPerRow) * itemWidth - 15;
    itemsContainer.style.width = `${optimalWidth}px`;
}

function showItems(category) {
    currentCategory = category.label;
    const itemsContainer = document.getElementById('items-container');
    itemsContainer.innerHTML = '';
    allItems = category.submenu;
    allItems.forEach(item => {
        const itemElement = createItemElement(item);
        itemsContainer.appendChild(itemElement);
    });
    document.getElementById('categories-container').classList.add('hidden');
    itemsContainer.classList.remove('hidden');
    document.getElementById('back-button').classList.remove('hidden');
    document.getElementById('sell-items').classList.remove('hidden');
    document.getElementById('buy-items').classList.remove('hidden');
    adjustItemsContainerWidth();
}

function createItemElement(item) {
    const itemDiv = document.createElement('div');
    itemDiv.className = 'item';
    
    const searchMode = document.getElementById('search-box').value !== '';
    
    if (searchMode) {
        const handleClick = (e) => {
            if (!e.target.classList.contains('item-quantity')) {
                const category = menuStructure.find(cat => 
                    cat.submenu.some(subItem => subItem.itemName === item.itemName)
                );
                if (category) {
                    document.getElementById('search-box').value = '';
                    showItems(category);
                }
            }
        };
        itemDiv.addEventListener('click', handleClick);
    }

    itemDiv.innerHTML = `
        <img src="nui://qb-inventory/html/images/${item.itemName}.png" alt="${item.label}">
        <div class="item-name">${item.label.split(' - ')[0]}</div>
        <div class="item-price">
            <span class="price-label">Sell:</span> <span class="price-value">${item.sellPrice}</span>
        </div>
        <div class="item-price">
            <span class="price-label">Buy:</span> <span class="price-value">${item.buyPrice}</span>
        </div>
        <input type="number" class="item-quantity" min="0" value="0" data-item="${item.itemName}">
    `;
    return itemDiv;
}

let isSearching = false;

function initializeSearch() {
    const searchBox = document.getElementById('search-box');
    searchBox.addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        isSearching = searchTerm !== '';
        
        if (!isSearching) {
            loadCategories(menuStructure);
            return;
        }
        
        const searchableItems = menuStructure.flatMap(category => category.submenu);
        const filteredItems = searchableItems.filter(item =>
            item.label.toLowerCase().includes(searchTerm) ||
            item.itemName.toLowerCase().includes(searchTerm)
        );
        
        displayFilteredItems(filteredItems);
        document.getElementById('items-container').classList.remove('hidden');
    });
}

function displayFilteredItems(items) {
    const itemsContainer = document.getElementById('items-container');
    itemsContainer.innerHTML = '';
    items.forEach(item => {
        const itemElement = createItemElement(item);
        itemsContainer.appendChild(itemElement);
    });
    adjustItemsContainerWidth();
}

document.getElementById('back-button').addEventListener('click', () => loadCategories(menuStructure));

document.getElementById('sell-items').addEventListener('click', function() {
    const itemsToSell = [];
    const quantityInputs = document.querySelectorAll('.item-quantity');
    quantityInputs.forEach(input => {
        const quantity = parseInt(input.value);
        if (quantity > 0) {
            if (input.dataset.item === 'markedbills') {
                fetch('https://ksp-pedvend/exchangeMarkedBills', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ quantity: quantity })
                });
            } else {
                itemsToSell.push({
                    name: input.dataset.item,
                    quantity: quantity
                });
            }
        }
    });

    if (itemsToSell.length > 0) {
        fetch('https://ksp-pedvend/sellItems', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ items: itemsToSell, category: currentCategory })
        });
    }
   
    document.getElementById('main-panel').style.display = 'none';
    fetch('https://ksp-pedvend/closeMenu', { method: 'POST' });
});

document.getElementById('buy-items').addEventListener('click', function() {
    const itemsToBuy = [];
    const quantityInputs = document.querySelectorAll('.item-quantity');
    quantityInputs.forEach(input => {
        const quantity = parseInt(input.value);
        if (quantity > 0) {
            itemsToBuy.push({
                name: input.dataset.item,
                quantity: quantity
            });
        }
    });

    if (itemsToBuy.length > 0) {
        fetch('https://ksp-pedvend/buyItems', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ items: itemsToBuy, category: currentCategory })
        });
    }
   
    document.getElementById('main-panel').style.display = 'none';
    fetch('https://ksp-pedvend/closeMenu', { method: 'POST' });
});

document.getElementById('close-menu').addEventListener('click', function() {
    fetch('https://ksp-pedvend/closeMenu', { method: 'POST' });
    document.getElementById('main-panel').style.display = 'none';
});

function getCategoryIcon(label) {
    switch(label.trim().toLowerCase()) {
        case 'weapons':
            return 'fas fa-crosshairs';
        case 'food':
            return 'fas fa-utensils';
        case 'drinks':
            return 'fas fa-glass-martini';
        case 'fireworks':
            return 'fas fa-fire';
        case 'items':
            return 'fas fa-box-open';
        case 'drugs':
            return 'fas fa-pills';
        case 'materials':
            return 'fas fa-cubes';
        case 'attachments':
            return 'fas fa-puzzle-piece';
        case 'cards':
            return 'fas fa-id-card';
        case 'ammo':
            return 'fas fa-bullseye';
        case 'tools':
            return 'fas fa-wrench';
        case 'mechanicparts':
            return 'fas fa-cogs';
        case 'communication':
            return 'fas fa-mobile-alt';
        case 'theftandjewelry':
            return 'fas fa-gem';
        case 'labkeys':
            return 'fas fa-key';
        case 'tuners':
            return 'fas fa-tachometer-alt';
        case 'vehicleparts':
            return 'fas fa-car';
        case 'marked bill exchange':
            return 'fas fa-money-bill-wave';
        default:
            return 'fas fa-list';
    }
}
