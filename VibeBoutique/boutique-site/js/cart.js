import { updateCartBadge } from "./main.js";

document.addEventListener("DOMContentLoaded", () => {
  renderCart();
});

// Main function to load and render cart elements
function renderCart() {
  const container = document.getElementById("cart-content-wrapper");
  if (!container) return;

  let cart = [];
  try {
    cart = JSON.parse(localStorage.getItem("boutique_cart") || "[]");
  } catch (e) {
    console.error("Failed to parse cart items:", e);
    cart = [];
  }

  if (cart.length === 0) {
    container.className = "empty-cart-message";
    container.innerHTML = `
      <i class="fas fa-shopping-bag" style="font-size: 4rem; color: var(--accent-gold-light); margin-bottom: var(--spacing-sm);"></i>
      <h2 style="margin-bottom: 0.5rem;">Your cart is empty</h2>
      <p class="text-muted" style="margin-bottom: var(--spacing-md);">Looks like you haven't added anything to your cart yet.</p>
      <a href="shop.html" class="btn btn-primary">Start Shopping</a>
    `;
    return;
  }

  // Restore two-column grid class
  container.className = "cart-layout";

  // Build the table rows html
  let itemsHtml = `
    <div>
      <table class="cart-items-table">
        <thead>
          <tr>
            <th class="cart-th" style="width: 50%;">Product</th>
            <th class="cart-th" style="width: 20%;">Price</th>
            <th class="cart-th" style="width: 20%;">Quantity</th>
            <th class="cart-th" style="width: 10%;">Remove</th>
          </tr>
        </thead>
        <tbody>
  `;

  let subtotal = 0;

  cart.forEach((item, index) => {
    const itemTotal = item.price * item.qty;
    subtotal += itemTotal;
    
    // Check optional variants display
    const variantDesc = [item.variant?.size, item.variant?.color].filter(Boolean).join(" / ");

    itemsHtml += `
      <tr class="cart-tr" id="cart-item-row-${index}">
        <td>
          <div class="cart-item-row">
            <img class="cart-item-img" src="${item.imageUrl || 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop'}" alt="${item.name}">
            <div class="cart-item-details">
              <a href="product.html?id=${item.productId}" class="cart-item-name">${item.name}</a>
              ${variantDesc ? `<span class="cart-item-meta">${variantDesc}</span>` : ''}
            </div>
          </div>
        </td>
        <td class="cart-item-price-td">₹${item.price.toFixed(2)}</td>
        <td>
          <div class="quantity-selector">
            <button class="qty-btn dec-qty-btn" data-index="${index}">-</button>
            <input type="text" class="qty-input cart-qty-input" data-index="${index}" value="${item.qty}" readonly>
            <button class="qty-btn inc-qty-btn" data-index="${index}">+</button>
          </div>
        </td>
        <td>
          <button class="cart-remove-btn delete-item-btn" data-index="${index}" aria-label="Remove item">
            <i class="fas fa-trash-can"></i>
          </button>
        </td>
      </tr>
    `;
  });

  itemsHtml += `
        </tbody>
      </table>
    </div>
  `;

  // Summary box
  const shippingNote = "Calculated at checkout";
  const summaryHtml = `
    <div class="cart-summary-card">
      <h3 class="cart-summary-title">Summary</h3>
      <div class="summary-row">
        <span class="text-muted">Subtotal</span>
        <span style="font-weight: 500;">₹${subtotal.toFixed(2)}</span>
      </div>
      <div class="summary-row" style="border-bottom: 1px solid var(--border-color); padding-bottom: 0.8rem;">
        <span class="text-muted">Shipping</span>
        <span style="font-size: 0.85rem; color: var(--text-muted);">${shippingNote}</span>
      </div>
      <div class="summary-row" style="margin-top: 0.5rem; margin-bottom: 0.5rem;">
        <span class="summary-total-label">Estimated Total</span>
        <span class="summary-total-val">₹${subtotal.toFixed(2)}</span>
      </div>
      <a href="checkout.html" class="btn btn-primary" style="width: 100%; margin-top: 0.5rem; text-align: center;">
        Proceed To Checkout
      </a>
      <a href="shop.html" class="text-center" style="font-size: 0.85rem; text-decoration: underline; margin-top: 0.5rem;">
        Continue Shopping
      </a>
    </div>
  `;

  container.innerHTML = itemsHtml + summaryHtml;

  // Bind actions
  setupCartActions(cart);
}

function setupCartActions(cart) {
  // Decrement Quantity
  document.querySelectorAll(".dec-qty-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const idx = parseInt(btn.getAttribute("data-index"));
      if (cart[idx].qty > 1) {
        cart[idx].qty--;
        saveAndReload(cart);
      }
    });
  });

  // Increment Quantity
  document.querySelectorAll(".inc-qty-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const idx = parseInt(btn.getAttribute("data-index"));
      const maxStock = cart[idx].maxStock || 999;
      if (cart[idx].qty < maxStock) {
        cart[idx].qty++;
        saveAndReload(cart);
      } else {
        alert(`Sorry, only ${maxStock} items are available in stock.`);
      }
    });
  });

  // Delete Item
  document.querySelectorAll(".delete-item-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const idx = parseInt(btn.getAttribute("data-index"));
      
      // Add a fading class to visual row first
      const row = document.getElementById(`cart-item-row-${idx}`);
      if (row) {
        row.style.transition = "opacity 0.3s ease";
        row.style.opacity = "0";
        setTimeout(() => {
          cart.splice(idx, 1);
          saveAndReload(cart);
        }, 300);
      } else {
        cart.splice(idx, 1);
        saveAndReload(cart);
      }
    });
  });
}

function saveAndReload(cart) {
  localStorage.setItem("boutique_cart", JSON.stringify(cart));
  updateCartBadge();
  renderCart();
}
export { renderCart };
