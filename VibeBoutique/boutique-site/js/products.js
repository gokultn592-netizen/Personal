import { collection, getDocs, query, orderBy } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { db, isConfigured } from "./firebase-config.js";

// Main products state
let allProducts = [];
let activeCategory = "all";
let searchQuery = "";
let sortBy = "featured";

// Fallback high-quality mock items
const mockProducts = [
  {
    id: "mock1",
    name: "Linen Gold Trim Kimono",
    description: "Relaxed fit lounge kimono made from pure organic flax linen, featuring delicate gold thread trimmings along the edges.",
    price: 180.00,
    category: "Lounge",
    featured: true,
    imageUrl: "https://images.unsplash.com/photo-1544441893-675973e31985?w=600&auto=format&fit=crop",
    stock: 5,
    sizes: ["S", "M", "L"],
    colors: ["Ivory", "Sandy Beige"],
    createdAt: { seconds: Date.now() / 1000 - 86400 * 2 }
  },
  {
    id: "mock2",
    name: "Velvet Double-Breasted Blazer",
    description: "Ultra-soft velvet blazer tailored to perfection. Structure shoulder pads, double-breasted buttoning, and interior silk pocket linings.",
    price: 240.00,
    category: "Tailoring",
    featured: true,
    imageUrl: "https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=600&auto=format&fit=crop",
    stock: 2,
    sizes: ["M", "L"],
    colors: ["Midnight Blue", "Crimson Velvet"],
    createdAt: { seconds: Date.now() / 1000 - 86400 * 10 }
  },
  {
    id: "mock3",
    name: "Ribbed Merino Knit Dress",
    description: "Elegant ankle-length ribbed midi dress constructed from pure, fine merino wool. Body-hugging fit with lightweight thermal protection.",
    price: 195.00,
    category: "Knitwear",
    featured: true,
    imageUrl: "https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=600&auto=format&fit=crop",
    stock: 12,
    sizes: ["XS", "S", "M"],
    colors: ["Sage Green", "Charcoal Gray"],
    createdAt: { seconds: Date.now() / 1000 - 86400 }
  },
  {
    id: "mock4",
    name: "Minimalist Brass Buckle Belt",
    description: "Unisex full-grain calfskin leather belt with custom brushed brass buckle. Handcrafted and burnished edges.",
    price: 85.00,
    category: "Accessories",
    featured: true,
    imageUrl: "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=600&auto=format&fit=crop",
    stock: 0,
    sizes: ["One Size"],
    colors: ["Chestnut Brown", "Noir Black"],
    createdAt: { seconds: Date.now() / 1000 - 86400 * 30 }
  },
  {
    id: "mock5",
    name: "Silk Satin Slip Dress",
    description: "Premium heavy-weight mulberry silk slip dress with adjustable cross-back straps, bias-cut silhouette for a fluid drape.",
    price: 220.00,
    category: "Eveningwear",
    featured: false,
    imageUrl: "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600&auto=format&fit=crop",
    stock: 7,
    sizes: ["S", "M", "L"],
    colors: ["Champagne Gold", "Classic Black"],
    createdAt: { seconds: Date.now() / 1000 - 86400 * 5 }
  },
  {
    id: "mock6",
    name: "Oversized Cotton Trench Coat",
    description: "Classic double-breasted storm flap cotton trench. Removable belt, adjustable cuff straps, windproof lining.",
    price: 280.00,
    category: "Outerwear",
    featured: false,
    imageUrl: "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=600&auto=format&fit=crop",
    stock: 4,
    sizes: ["S", "M", "L", "XL"],
    colors: ["Khaki Stone", "Navy Blue"],
    createdAt: { seconds: Date.now() / 1000 - 86400 * 3 }
  },
  {
    id: "mock7",
    name: "Leather Pointed Mules",
    description: "Handcrafted soft nappa leather mules featuring an elegant pointed toe profile and a subtle stacked wood heel.",
    price: 160.00,
    category: "Shoes",
    featured: false,
    imageUrl: "https://images.unsplash.com/photo-1539185441755-769473a23570?w=600&auto=format&fit=crop",
    stock: 3,
    sizes: ["37", "38", "39", "40"],
    colors: ["Warm Tan", "Onyx Black"],
    createdAt: { seconds: Date.now() / 1000 - 86400 * 15 }
  }
];

document.addEventListener("DOMContentLoaded", async () => {
  const grid = document.getElementById("products-grid");
  if (!grid) return;

  // Initialize
  await loadProducts();
  setupFilters();
  setupSearch();
  setupSorting();
  
  // Handle URL query parameters (e.g. ?category=Lounge or ?filter=new)
  handleQueryParams();
  
  renderProducts();
});

// Load catalog products
async function loadProducts() {
  if (!isConfigured) {
    console.log("Using mock products data.");
    allProducts = [...mockProducts];
    return;
  }

  try {
    const q = query(collection(db, "products"));
    const querySnapshot = await getDocs(q);
    
    if (querySnapshot.empty) {
      console.log("Firestore products collection is empty. Using mock data.");
      allProducts = [...mockProducts];
    } else {
      allProducts = [];
      querySnapshot.forEach(doc => {
        allProducts.push({
          id: doc.id,
          ...doc.data()
        });
      });
    }
  } catch (error) {
    console.error("Error loading products from Firestore: ", error);
    allProducts = [...mockProducts];
  }
}

// Extract categories and build filter UI
function setupFilters() {
  const tabContainer = document.getElementById("category-tabs");
  if (!tabContainer) return;

  // Find unique categories from product list
  const categories = [...new Set(allProducts.map(p => p.category).filter(Boolean))];
  
  // Clear any dynamic additions
  tabContainer.innerHTML = '<li class="filter-tab active" data-category="all">All</li>';
  
  categories.forEach(category => {
    const li = document.createElement("li");
    li.className = "filter-tab";
    li.setAttribute("data-category", category);
    li.textContent = category;
    tabContainer.appendChild(li);
  });

  // Attach click listener
  tabContainer.addEventListener("click", (e) => {
    const tab = e.target.closest(".filter-tab");
    if (!tab) return;

    // Toggle active state
    document.querySelectorAll(".filter-tab").forEach(t => t.classList.remove("active"));
    tab.classList.add("active");

    activeCategory = tab.getAttribute("data-category");
    renderProducts();
  });
}

// Search field bindings
function setupSearch() {
  const searchInput = document.getElementById("search-input");
  if (!searchInput) return;

  searchInput.addEventListener("input", (e) => {
    searchQuery = e.target.value.toLowerCase().trim();
    renderProducts();
  });
}

// Sorting bindings
function setupSorting() {
  const sortSelect = document.getElementById("sort-select");
  if (!sortSelect) return;

  sortSelect.addEventListener("change", (e) => {
    sortBy = e.target.value;
    renderProducts();
  });
}

// URL parameters mapping
function handleQueryParams() {
  const params = new URLSearchParams(window.location.search);
  const catParam = params.get("category");
  const filterParam = params.get("filter");

  if (catParam) {
    activeCategory = catParam;
    const matchingTab = document.querySelector(`.filter-tab[data-category="${catParam}"]`);
    if (matchingTab) {
      document.querySelectorAll(".filter-tab").forEach(t => t.classList.remove("active"));
      matchingTab.classList.add("active");
    }
  } else if (filterParam === "new") {
    // Set sorting to newest arrivals
    sortBy = "newest";
    const sortSelect = document.getElementById("sort-select");
    if (sortSelect) sortSelect.value = "newest";
  }
}

// Filter and Sort dataset, then render into DOM
function renderProducts() {
  const grid = document.getElementById("products-grid");
  if (!grid) return;

  // 1. Filtering
  let filtered = allProducts.filter(product => {
    // Category check
    const matchesCategory = activeCategory === "all" || product.category === activeCategory;
    
    // Search check
    const matchesSearch = !searchQuery || 
      product.name.toLowerCase().includes(searchQuery) || 
      (product.description && product.description.toLowerCase().includes(searchQuery));
      
    return matchesCategory && matchesSearch;
  });

  // 2. Sorting
  filtered.sort((a, b) => {
    if (sortBy === "price-asc") {
      return a.price - b.price;
    } else if (sortBy === "price-desc") {
      return b.price - a.price;
    } else if (sortBy === "newest") {
      const timeA = a.createdAt?.seconds || 0;
      const timeB = b.createdAt?.seconds || 0;
      return timeB - timeA;
    } else {
      // Default: Featured first, then alphabetical
      if (a.featured && !b.featured) return -1;
      if (!a.featured && b.featured) return 1;
      return a.name.localeCompare(b.name);
    }
  });

  // 3. Render cards
  if (filtered.length === 0) {
    grid.innerHTML = `
      <div class="text-center text-muted" style="grid-column: 1 / -1; padding: var(--spacing-lg) 0;">
        <i class="fas fa-search" style="font-size: 2rem; color: var(--accent-gold); margin-bottom: var(--spacing-sm);"></i>
        <p>No products found matching your criteria.</p>
      </div>`;
    return;
  }

  let html = "";
  filtered.forEach(product => {
    const outOfStock = product.stock <= 0;
    
    html += `
      <article class="product-card">
        <a href="product.html?id=${product.id}" class="product-image-wrapper">
          <img class="product-img" src="${product.imageUrl || 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop'}" alt="${product.name}" loading="lazy">
          ${product.featured ? '<span class="product-badge featured">Featured</span>' : ''}
          ${outOfStock ? '<span class="product-badge" style="background-color: #8C3E3E; color: white; top: auto; bottom: 12px;">Sold Out</span>' : ''}
        </a>
        <div class="product-info">
          <span class="product-category">${product.category || 'Garments'}</span>
          <a href="product.html?id=${product.id}"><h3 class="product-title">${product.name}</h3></a>
          <div class="product-price">$${Number(product.price).toFixed(2)}</div>
        </div>
      </article>
    `;
  });
  grid.innerHTML = html;
}
export { allProducts, mockProducts };
