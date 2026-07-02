import { updateCartBadge } from "./main.js";
import { db, isConfigured, auth } from "./firebase-config.js";
import { collection, query, where, getDocs } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

document.addEventListener("DOMContentLoaded", () => {
  renderCart();

  // Natively listen to Firebase Auth state updates directly (no race conditions!)
  auth.onAuthStateChanged((user) => {
    if (user) {
      loadUserOrderHistory(user);
    } else {
      showGuestOrderHistoryMessage();
    }
  });
});

function showGuestOrderHistoryMessage() {
  const historySection = document.getElementById("order-history-section");
  const historyContainer = document.getElementById("order-history-container");
  if (!historySection || !historyContainer) return;

  historySection.style.display = "block";
  historyContainer.innerHTML = `
    <div class="text-center text-muted" style="padding: var(--spacing-lg) 0; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: var(--radius-md);">
      <i class="fas fa-user-lock" style="font-size: 2.2rem; color: var(--accent-gold); margin-bottom: 0.6rem; opacity: 0.8;"></i>
      <p style="font-size: 0.92rem; max-width: 320px; margin: 0 auto 1rem;">Sign in with your Google account to view your past orders and returns tracking.</p>
      <button id="cart-guest-signin-btn" class="btn btn-pill" style="padding: 0.45rem 1.5rem !important; font-size: 0.78rem !important; background: var(--accent-gold); color: var(--bg-dark); border: none; font-weight: 600; cursor: pointer;">
        Sign In to Track Orders
      </button>
    </div>
  `;

  const btn = document.getElementById("cart-guest-signin-btn");
  if (btn) {
    btn.addEventListener("click", () => {
      import("./main.js").then(m => m.showSignInOverlay());
    });
  }
}

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
      <a href="returns.html" class="text-center" style="font-size: 0.85rem; margin-top: 0.3rem; display: flex; align-items: center; justify-content: center; gap: 0.3rem; color: var(--accent-gold); text-decoration: none;">
        <i class="fas fa-rotate-left" style="font-size: 0.78rem;"></i> Returns & Exchange
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

// Load and Render Buyer's Order History & Returns tracking
async function loadUserOrderHistory(user) {
  const historySection = document.getElementById("order-history-section");
  const historyContainer = document.getElementById("order-history-container");
  if (!historySection || !historyContainer) return;

  let orders = [];
  let returns = [];

  console.log("loadUserOrderHistory: Starting history fetch. isConfigured =", isConfigured, "User UID =", user.uid);

  if (isConfigured) {
    try {
      console.log("loadUserOrderHistory: Querying orders for buyerUid =", user.uid);
      // 1. Fetch user orders from Firestore (without orderBy to avoid index requirement)
      const ordersQuery = query(
        collection(db, "orders"),
        where("buyerUid", "==", user.uid)
      );
      const ordersSnap = await getDocs(ordersQuery);
      ordersSnap.forEach(doc => {
        orders.push({ id: doc.id, ...doc.data() });
      });

      console.log("loadUserOrderHistory: Successfully fetched orders count =", orders.length);

      // Sort orders in-memory (newest first)
      orders.sort((a, b) => {
        const timeA = a.createdAt?.seconds || (a.createdAt ? new Date(a.createdAt).getTime() / 1000 : 0);
        const timeB = b.createdAt?.seconds || (b.createdAt ? new Date(b.createdAt).getTime() / 1000 : 0);
        return timeB - timeA;
      });

      console.log("loadUserOrderHistory: Querying returns for buyerUid =", user.uid);
      // 2. Fetch user returns from Firestore
      const returnsQuery = query(
        collection(db, "returns"),
        where("buyerUid", "==", user.uid)
      );
      const returnsSnap = await getDocs(returnsQuery);
      returnsSnap.forEach(doc => {
        returns.push({ id: doc.id, ...doc.data() });
      });

      console.log("loadUserOrderHistory: Successfully fetched returns count =", returns.length);

      // Sort returns in-memory (newest first)
      returns.sort((a, b) => {
        const timeA = a.createdAt?.seconds || (a.createdAt ? new Date(a.createdAt).getTime() / 1000 : 0);
        const timeB = b.createdAt?.seconds || (b.createdAt ? new Date(b.createdAt).getTime() / 1000 : 0);
        return timeB - timeA;
      });
    } catch (e) {
      console.error("loadUserOrderHistory: Firestore query failed! Error details:", e);
      orders = getMockUserOrders(user);
      returns = getMockUserReturns(user);
    }
  } else {
    console.log("loadUserOrderHistory: Demo mode active. Loading mock data from LocalStorage.");
    orders = getMockUserOrders(user);
    returns = getMockUserReturns(user);
  }

  // Always display the tracker section if user is logged in
  historySection.style.display = "block";

  if (orders.length === 0) {
    historyContainer.innerHTML = `
      <div class="text-center text-muted" style="padding: var(--spacing-lg) 0; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: var(--radius-md);">
        <i class="fas fa-box-open" style="font-size: 2.2rem; color: var(--accent-gold); margin-bottom: 0.6rem; opacity: 0.8;"></i>
        <p style="font-size: 0.92rem; max-width: 320px; margin: 0 auto;">No past orders found. Once you place an order, it will show up here for status tracking and returns.</p>
      </div>
    `;
    return;
  }

  // Build returns lookup map: orderId -> productName -> status
  const returnMap = {};
  returns.forEach(ret => {
    if (ret.orderId) {
      if (!returnMap[ret.orderId]) {
        returnMap[ret.orderId] = {};
      }
      returnMap[ret.orderId][ret.product] = {
        id: ret.id,
        status: ret.status || "pending",
        type: ret.type || "return"
      };
    }
  });

  // Render orders
  historyContainer.innerHTML = orders.map(order => {
    let dateStr = "—";
    if (order.createdAt) {
      const d = order.createdAt.seconds
        ? new Date(order.createdAt.seconds * 1000)
        : new Date(order.createdAt);
      dateStr = d.toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
    }

    const itemsHtml = (order.items || []).map(item => {
      const variantDesc = [item.variant?.size, item.variant?.color].filter(Boolean).join(" / ");
      
      // Check return request status lookup
      const returnRequest = returnMap[order.id]?.[item.name];
      let returnActionHtml = "";

      if (returnRequest) {
        // Return already requested, show status badge
        const retStatusColors = {
          pending: "background: rgba(234,179,8,0.12); color: #eab308;",
          approved: "background: rgba(34,197,94,0.12); color: #22c55e;",
          rejected: "background: rgba(239,68,68,0.12); color: #ef4444;",
          completed: "background: rgba(59,130,246,0.15); color: #3b82f6;"
        };
        const style = retStatusColors[returnRequest.status] || retStatusColors.pending;
        const typeLabel = returnRequest.type === "exchange" ? "Exchange" : "Return";
        returnActionHtml = `
          <div style="text-align: right;">
            <span class="tracker-badge" style="${style}">${typeLabel} ${returnRequest.status}</span>
          </div>
        `;
      } else if (order.status === "completed" || order.status === "shipped") {
        // Return option only available for fulfilled orders (matching real store workflow)
        const returnUrl = `returns.html?orderId=${order.id}&name=${encodeURIComponent(order.customerName)}&phone=${encodeURIComponent(order.phone)}&product=${encodeURIComponent(item.name + (variantDesc ? ' — ' + variantDesc : ''))}`;
        returnActionHtml = `
          <a href="${returnUrl}" class="btn btn-secondary btn-tracker-action btn-pill" style="padding: 0.35rem 0.9rem !important; font-size: 0.72rem !important;">
            Return or Exchange
          </a>
        `;
      }

      return `
        <div class="tracker-item-row">
          <img class="tracker-item-img" src="${item.imageUrl || 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop'}" alt="${item.name}">
          <div class="tracker-item-details">
            <h4 class="tracker-item-name">${item.name}</h4>
            ${variantDesc ? `<span class="tracker-item-meta">${variantDesc}</span>` : ""}
            <div class="tracker-item-qty">Qty: ${item.qty}</div>
          </div>
          <div>
            <div style="font-weight: 600; font-size: 0.9rem; margin-bottom: 0.4rem; text-align: right;">₹${(item.price * item.qty).toFixed(2)}</div>
            ${returnActionHtml}
          </div>
        </div>
      `;
    }).join("");

    // Setup order status badge
    let statusClass = "badge-pending";
    if (order.status === "shipped") statusClass = "badge-shipped";
    if (order.status === "completed") statusClass = "badge-delivered";
    if (order.status === "cancelled") statusClass = "badge-cancelled";
    if (order.status === "refunded") statusClass = "badge-refunded";

    return `
      <div class="tracker-card">
        <div class="tracker-header">
          <div class="tracker-header-info">
            <div>
              <div class="tracker-header-label">Order Placed</div>
              <div class="tracker-header-val">${dateStr}</div>
            </div>
            <div>
              <div class="tracker-header-label">Total Amount</div>
              <div class="tracker-header-val" style="font-weight: 600;">₹${order.total.toFixed(2)}</div>
            </div>
            <div>
              <div class="tracker-header-label">Ship To</div>
              <div class="tracker-header-val">${order.customerName}</div>
            </div>
          </div>
          <div>
            <span class="tracker-header-label" style="display: block; text-align: right;">Order ID</span>
            <span class="tracker-order-id">#${order.id}</span>
          </div>
        </div>
        <div class="tracker-body">
          <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(0, 0, 0, 0.05); padding-bottom: 0.6rem; margin-bottom: 0.4rem;">
            <div style="font-weight: 600; font-size: 0.92rem; text-transform: uppercase; color: var(--text-muted);">Status</div>
            <span class="tracker-badge ${statusClass}">${order.status}</span>
          </div>
          ${itemsHtml}
        </div>
      </div>
    `;
  }).join("");
}

// Local storage fallback helpers for mock demo mode
function getMockUserOrders(user) {
  const savedOrders = JSON.parse(localStorage.getItem("boutique_mock_orders") || "[]");
  // Match user's orders, including legacy orders without buyerUid
  return savedOrders.filter(order => !order.buyerUid || order.buyerUid === user.uid);
}

function getMockUserReturns(user) {
  const savedReturns = JSON.parse(localStorage.getItem("boutique_mock_returns") || "[]");
  // Match user's returns, including legacy returns without buyerUid
  return savedReturns.filter(ret => !ret.buyerUid || ret.buyerUid === user.uid);
}
