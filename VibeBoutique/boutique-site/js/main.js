import { doc, getDoc } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { db, isConfigured } from "./firebase-config.js";
import { waitForAuthState, resolveRole, signInWithGoogle, signOutUser } from "./auth.js";

// Global state
let appSettings = {
  whatsappNumber: "1234567890",
  shopName: "Joe Boutique",
  instagramId: "vibeboutique",
  upiId: "vibe.boutique@okaxis"
};

// Helper: format shop name into brand display (e.g. "Joe Boutique" → "JOE<span>BOUTIQUE</span>")
function formatBrandHtml(name) {
  const words = (name || "Joe Boutique").trim().split(/\s+/);
  if (words.length === 1) return `<span style="color: var(--accent-gold);">${words[0].toUpperCase()}</span>`;
  const last = words.pop().toUpperCase();
  const first = words.map(w => w.toUpperCase()).join("");
  return `${first}<span style="color: var(--accent-gold);">${last}</span>`;
}

// Shared auth state — set once, used everywhere on the page
export let currentUser = null;
export let currentRole = null;   // "admin" | "buyer" | null

// Global HTML Escape Utility to mitigate XSS
window.escapeHtml = (str) => {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
};

// ─────────────────────────────────────────────────────────
// BOOT — runs on every page
// ─────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", async () => {
  // Always inject FontAwesome so icons are loaded for all pages/users
  injectFontAwesome();

  // 1. Render layout placeholders immediately to prevent blank loading flash
  renderHeader();
  renderFooter();
  updateCartBadge();
  updateWishlistBadge();
  setupMobileMenu();

  // 2. Fetch Firebase settings asynchronously in background
  const fetchSettings = (async () => {
    if (isConfigured) {
      try {
        const settingsSnap = await getDoc(doc(db, "settings", "general"));
        if (settingsSnap.exists()) {
          const data = settingsSnap.data();
          if (data.whatsappNumber) appSettings.whatsappNumber = data.whatsappNumber.replace(/[\s\-\+\(\)]/g, "");
          if (data.shopName) appSettings.shopName = data.shopName;
          if (data.instagramId) appSettings.instagramId = data.instagramId.trim().replace(/@/g, "");
          if (data.upiId) appSettings.upiId = data.upiId.trim();
          window.dispatchEvent(new CustomEvent("settingsLoaded", { detail: appSettings }));
        }
      } catch (e) {
        console.warn("Could not load settings:", e);
      }
    } else {
      // Load mock settings in demo mode
      const saved = localStorage.getItem("boutique_mock_settings");
      if (saved) {
        try {
          const data = JSON.parse(saved);
          if (data.whatsappNumber) appSettings.whatsappNumber = data.whatsappNumber.replace(/[\s\-\+\(\)]/g, "");
          if (data.shopName) appSettings.shopName = data.shopName;
          if (data.instagramId) appSettings.instagramId = data.instagramId.trim().replace(/@/g, "");
          if (data.upiId) appSettings.upiId = data.upiId.trim();
          window.dispatchEvent(new CustomEvent("settingsLoaded", { detail: appSettings }));
        } catch (e) {}
      }
    }
  })();

  // 3. Check auth state asynchronously in parallel
  const fetchAuth = (async () => {
    const user = await waitForAuthState();
    currentUser = user;
    if (user) {
      currentRole = await resolveRole(user);
    }

    // Re-render header to update the user account avatar / dropdown dropdown dynamically
    renderHeader();

    window.dispatchEvent(new CustomEvent("authReady", {
      detail: { user: currentUser, role: currentRole }
    }));
  })();

  // 4. Initialize persistent floating chat widget
  initFloatingChatWidget();
});

// ─────────────────────────────────────────────────────────
// SIGN-IN OVERLAY
// Full-screen gate shown to any visitor who is not signed in
// ─────────────────────────────────────────────────────────
export function showSignInOverlay() {
  // Inject FontAwesome first so icons load
  injectFontAwesome();

  // Prevent multiple overlays
  if (document.getElementById("signin-overlay")) return;

  const overlay = document.createElement("div");
  overlay.id = "signin-overlay";
  overlay.style.cssText = `
    position: fixed; inset: 0; z-index: 9999;
    background: rgba(10, 10, 10, 0.85);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    display: flex; align-items: center; justify-content: center;
    font-family: 'Outfit', sans-serif;
  `;

  overlay.innerHTML = `
    <div style="
      text-align: center;
      max-width: 420px;
      width: 90%;
      padding: 3rem 2.5rem;
      background: rgba(18, 18, 18, 0.95);
      backdrop-filter: blur(12px);
      border: 1px solid var(--glass-border);
      border-radius: 12px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.6);
      position: relative;
    ">
      <!-- Close Button -->
      <button id="signin-close-btn" style="
        position: absolute; top: 15px; right: 15px;
        background: none; border: none; color: #FAF9F6;
        opacity: 0.6; cursor: pointer; font-size: 1.25rem;
        transition: opacity var(--transition-fast);
      " onmouseover="this.style.opacity='1'" onmouseout="this.style.opacity='0.6'">
        <i class="fas fa-xmark"></i>
      </button>
      <!-- Logo -->
      <div style="
        font-family: 'Playfair Display', Georgia, serif;
        font-size: 2.2rem;
        font-weight: 600;
        letter-spacing: 0.05em;
        margin-bottom: 0.25rem;
        color: #FAF9F6;
      ">
        ${formatBrandHtml(appSettings.shopName)}
      </div>

      <p style="color: var(--text-muted); font-size: 0.9rem; margin-bottom: 2.5rem; letter-spacing: 0.05em;">
        A curated line of premium styles
      </p>

      <!-- Divider -->
      <div style="
        border-top: 1px solid #1f1f1f;
        margin-bottom: 2rem;
        position: relative;
      ">
        <span style="
          position: absolute; top: -0.6rem; left: 50%; transform: translateX(-50%);
          background: rgba(18, 18, 18, 0.95);
          padding: 0 0.75rem;
          font-size: 0.75rem;
          text-transform: uppercase;
          letter-spacing: 0.15em;
          color: var(--text-muted);
        ">Welcome</span>
      </div>

      <p style="font-size: 1rem; color: #FAF9F6; font-weight: 500; margin-bottom: 1.5rem;">
        Sign in to browse and shop
      </p>

      <!-- Google Sign-In Button -->
      <button id="google-signin-btn" style="
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.75rem;
        width: 100%;
        padding: 0.85rem 1.5rem;
        background: #121212;
        border: 1.5px solid var(--border-color);
        border-radius: 6px;
        font-family: 'Outfit', sans-serif;
        font-size: 0.95rem;
        font-weight: 500;
        color: #FAF9F6;
        cursor: pointer;
        transition: all 0.2s ease;
        box-shadow: 0 2px 8px rgba(0,0,0,0.4);
      ">
        <!-- Google SVG logo -->
        <svg width="20" height="20" viewBox="0 0 48 48">
          <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
          <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
          <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
          <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
        </svg>
        Continue with Google
      </button>

      <p id="signin-error" style="
        display: none;
        margin-top: 1rem;
        font-size: 0.8rem;
        color: #A34E4E;
        background: #FDF2F2;
        border: 1px solid #F8B4B4;
        padding: 0.5rem 0.75rem;
        border-radius: 4px;
      "></p>

      <p style="margin-top: 2rem; font-size: 0.75rem; color: var(--text-muted); line-height: 1.6;">
        By signing in you agree to receive order<br>confirmations via WhatsApp.
      </p>
    </div>
  `;

  document.body.appendChild(overlay);

  // Button interaction
  const btn = document.getElementById("google-signin-btn");
  const errEl = document.getElementById("signin-error");

  btn.addEventListener("mouseenter", () => {
    btn.style.borderColor = "var(--accent-gold)";
    btn.style.boxShadow = "0 4px 16px rgba(201,164,85,0.25)";
    btn.style.transform = "translateY(-1px)";
    btn.style.backgroundColor = "var(--bg-dark-gray)";
  });
  btn.addEventListener("mouseleave", () => {
    btn.style.borderColor = "var(--border-color)";
    btn.style.boxShadow = "0 2px 8px rgba(0,0,0,0.4)";
    btn.style.transform = "translateY(0)";
    btn.style.backgroundColor = "#121212";
  });

  btn.addEventListener("click", async () => {
    btn.disabled = true;
    btn.textContent = "Signing in…";
    btn.style.opacity = "0.7";
    if (errEl) errEl.style.display = "none";

    try {
      await signInWithGoogle();
      // Page will reload after sign-in
    } catch (err) {
      btn.disabled = false;
      btn.innerHTML = `
        <svg width="20" height="20" viewBox="0 0 48 48">
          <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
          <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
          <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
          <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
        </svg>
        Continue with Google`;
      btn.style.opacity = "1";
      if (errEl) {
        errEl.textContent = "Sign-in was cancelled or failed. Please try again.";
        errEl.style.display = "block";
      }
    }
  });

  // Bind close button event to dismiss the overlay
  const closeBtn = document.getElementById("signin-close-btn");
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      overlay.remove();
    });
  }
}

// ─────────────────────────────────────────────────────────
// CART BADGE
// ─────────────────────────────────────────────────────────
export function getCartCount() {
  try {
    const cart = JSON.parse(localStorage.getItem("boutique_cart") || "[]");
    return cart.reduce((total, item) => total + item.qty, 0);
  } catch (e) {
    return 0;
  }
}

export function updateCartBadge() {
  const count = getCartCount();
  document.querySelectorAll(".cart-count-badge").forEach(badge => {
    badge.textContent = count;
    badge.style.display = count > 0 ? "flex" : "none";
  });
}

// ─────────────────────────────────────────────────────────
// HEADER — role-aware, shows Admin link only for admins
// ─────────────────────────────────────────────────────────
function renderHeader() {
  const header = document.querySelector("header");
  if (!header) return;

  const path = window.location.pathname;
  const isAdmin = path.includes("/admin/");
  const base = isAdmin ? "../" : "./";
  const adminBase = isAdmin ? "./" : "admin/";

  // User avatar fallback
  const avatar = currentUser
    ? (currentUser.photoURL
        ? `<img src="${currentUser.photoURL}" style="width:32px;height:32px;border-radius:50%;object-fit:cover;border:2px solid var(--accent-gold);" alt="avatar">`
        : `<div style="width:32px;height:32px;border-radius:50%;background:var(--accent-gold);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:0.85rem;color:var(--bg-dark);">${(currentUser.displayName || currentUser.email || "?")[0].toUpperCase()}</div>`)
    : `<div style="width:32px;height:32px;border-radius:50%;background:transparent;border:2px solid var(--accent-gold);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:0.85rem;color:var(--accent-gold);" title="Sign In"><i class="fas fa-user" style="font-size: 0.85rem;"></i></div>`;

  // Admin portal link — only visible to admins
  const adminNavLink = currentRole === "admin"
    ? `<li><a href="${base}${adminBase}dashboard.html" class="${path.includes("dashboard") ? "active" : ""}">Admin Portal</a></li>`
    : "";

  const escapedName = currentUser ? window.escapeHtml(currentUser.displayName || "User") : "Guest Shopper";
  const escapedEmail = currentUser ? window.escapeHtml(currentUser.email) : "Browse & Checkout";

  header.innerHTML = `
    <!-- Top Promo Strip -->
    <div class="promo-strip">
      EASY 7-DAY EXCHANGE | DIRECT UPI PAYMENT
    </div>

    <div class="container navbar">
      <a href="${base}index.html" class="nav-brand" id="nav-brand-link" style="font-family: var(--font-heading); letter-spacing: 0.1em;">${formatBrandHtml(appSettings.shopName)}</a>
      <nav>
        <ul class="nav-links">
          <li><a href="${base}index.html" class="${(path.endsWith("index.html") || path.endsWith("/")) ? "active" : ""}">Home</a></li>
          <li><a href="${base}shop.html" class="${(path.endsWith("shop.html") && !window.location.search.includes("filter=wishlist")) ? "active" : ""}">Shop</a></li>
          <li><a href="${base}cart.html" class="${path.endsWith("cart.html") ? "active" : ""}">Cart</a></li>
          ${adminNavLink}
        </ul>
      </nav>
      
      <div class="nav-right-group">
        <!-- Search capsule -->
        <form action="${base}shop.html" method="GET" class="nav-search-form">
          <div class="nav-search-wrapper">
            <input type="text" name="search" class="nav-search-input" placeholder="Search items..." value="${window.escapeHtml(new URLSearchParams(window.location.search).get('search') || '')}">
            <button type="submit" class="nav-search-btn" aria-label="Search">
              <i class="fas fa-search"></i>
            </button>
          </div>
        </form>

        <div class="nav-icons" style="gap: 0.8rem;">
          <!-- Wishlist icon -->
          <a href="${base}shop.html?filter=wishlist" class="nav-icon-btn" aria-label="Wishlist" title="View Wishlist" style="position: relative;">
            <i class="far fa-heart"></i>
            <span class="wishlist-count-badge" style="display:none;">0</span>
          </a>
          
          <!-- Cart icon -->
          <a href="${base}cart.html" class="nav-icon-btn" aria-label="Cart" title="View Cart" style="position: relative;">
            <i class="fas fa-shopping-bag"></i>
            <span class="cart-count-badge" style="display:none;">0</span>
          </a>
          
          <!-- User avatar + dropdown -->
          <div class="user-menu-wrapper" style="position:relative;">
            <button id="user-avatar-btn" class="nav-icon-btn" style="padding:0;" aria-label="Account menu">
              ${avatar}
            </button>
            <div id="user-dropdown" class="glass-panel" style="
              display: none;
              position: absolute; top: calc(100% + 10px); right: 0;
              background: var(--bg-secondary); border: 1px solid var(--glass-border);
              border-radius: var(--radius-md); min-width: 220px;
              box-shadow: var(--shadow-lg); padding: 0.75rem;
              z-index: 200;
            ">
              <div style="padding: 0.5rem 0.5rem 0.75rem; border-bottom: 1px solid var(--border-color); margin-bottom: 0.5rem;">
                <div style="font-weight: 600; font-size: 0.9rem; color: var(--text-primary);">${escapedName}</div>
                <div style="font-size: 0.75rem; color: var(--text-muted); margin-top: 0.2rem;">${escapedEmail}</div>
                ${currentUser ? `
                <div style="font-size: 0.7rem; margin-top: 0.3rem;">
                  <span style="
                    display:inline-block; padding: 0.15rem 0.5rem;
                    background: ${currentRole === "admin" ? "var(--accent-gold-light)" : "var(--border-color)"};
                    color: ${currentRole === "admin" ? "var(--accent-gold)" : "var(--text-primary)"};
                    border-radius: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em;
                  ">${currentRole === "admin" ? "Admin" : "Buyer"}</span>
                </div>
                ` : ""}
              </div>
              ${currentUser ? `
              <button id="signout-btn" style="
                width: 100%; text-align: left; padding: 0.5rem;
                border-radius: 4px; font-size: 0.85rem; cursor: pointer;
                color: #A34E4E; background: none; border: none;
                display: flex; align-items: center; gap: 0.5rem;
                transition: background 0.15s;
              ">
                <i class="fas fa-arrow-right-from-bracket"></i> Sign out
              </button>
              ` : `
              <button id="signin-trigger-btn" style="
                width: 100%; text-align: left; padding: 0.5rem;
                border-radius: 4px; font-size: 0.85rem; cursor: pointer;
                color: var(--accent-gold); background: none; border: none;
                display: flex; align-items: center; gap: 0.5rem;
                transition: background 0.15s;
              ">
                <i class="fas fa-arrow-right-to-bracket"></i> Sign in
              </button>
              `}
            </div>
          </div>
          <!-- Mobile hamburger -->
          <button class="nav-icon-btn menu-toggle" aria-label="Toggle Menu">
            <i class="fas fa-bars"></i>
          </button>
        </div>
      </div>
    </div>
    <!-- Mobile menu -->
    <div id="mobile-menu" style="display:none; background:var(--bg-secondary); border-bottom:1px solid var(--border-color); padding: var(--spacing-sm) var(--spacing-md);">
      <ul style="list-style:none; display:flex; flex-direction:column; gap:var(--spacing-sm);">
        <li>
          <form action="${base}shop.html" method="GET" style="margin-bottom: var(--spacing-xs);">
            <div style="position:relative; width:100%;">
              <input type="text" name="search" placeholder="Search products..." style="width:100%; padding:0.5rem 1rem; border-radius:20px; background:var(--bg-primary); border:1px solid var(--border-color); color:var(--text-primary); font-size:0.85rem;">
              <button type="submit" style="position:absolute; right:12px; top:50%; transform:translateY(-50%); color:var(--text-muted); border:none; background:none;"><i class="fas fa-search"></i></button>
            </div>
          </form>
        </li>
        <li><a href="${base}index.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem;">Home</a></li>
        <li><a href="${base}shop.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem;">Shop</a></li>
        <li><a href="${base}cart.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem;">Cart</a></li>
        <li><a href="${base}shop.html?filter=wishlist" style="text-transform:uppercase; font-weight:500; font-size:0.9rem; color:var(--accent-gold);"><i class="far fa-heart" style="margin-right:4px;"></i> Wishlist</a></li>
        ${currentRole === "admin" ? `<li><a href="${base}${adminBase}dashboard.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem; color:var(--accent-gold);">Admin Portal</a></li>` : ""}
      </ul>
    </div>
  `;

  // Bind avatar dropdown toggle
  const avatarBtn = document.getElementById("user-avatar-btn");
  const dropdown = document.getElementById("user-dropdown");
  if (avatarBtn && dropdown) {
    avatarBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      dropdown.style.display = dropdown.style.display === "none" ? "block" : "none";
    });
    document.addEventListener("click", () => {
      dropdown.style.display = "none";
    });
  }

  // Bind sign-out button
  const signoutBtn = document.getElementById("signout-btn");
  if (signoutBtn) {
    signoutBtn.addEventListener("click", async () => {
      await signOutUser();
    });
  }

  // Bind sign-in trigger button
  const signinBtn = document.getElementById("signin-trigger-btn");
  if (signinBtn) {
    signinBtn.addEventListener("click", () => {
      showSignInOverlay();
    });
  }
}

// ─────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────
function renderFooter() {
  const footer = document.querySelector("footer");
  if (!footer) return;

  const path = window.location.pathname;
  const isAdmin = path.includes("/admin/");
  const base = isAdmin ? "../" : "./";

  footer.innerHTML = `
    <div class="container">
      <div class="footer-grid">
        <div class="footer-col">
          <div class="footer-brand" id="footer-brand-text">${formatBrandHtml(appSettings.shopName)}</div>
          <p class="text-muted" style="font-size:0.9rem; margin-top:0.5rem; max-width:300px;">
            A curated collection of premium garments and accessories for the contemporary wardrobe.
          </p>
        </div>
        <div class="footer-col">
          <h4>Navigate</h4>
          <ul>
            <li><a href="${base}shop.html">Shop Catalog</a></li>
            <li><a href="${base}cart.html">View Cart</a></li>
            <li><a href="${base}checkout.html">Checkout</a></li>
            <li><a href="${base}returns.html">Returns & Exchange</a></li>
          </ul>
        </div>
        <div class="footer-col">
          <h4>Connect</h4>
          <ul>
            <li><a id="footer-wa-link" href="https://wa.me/${appSettings.whatsappNumber}" target="_blank"><i class="fab fa-whatsapp"></i> Chat on WhatsApp</a></li>
            <li><a id="footer-ig-link" href="https://instagram.com/${appSettings.instagramId}" target="_blank"><i class="fab fa-instagram"></i> Instagram</a></li>
          </ul>
        </div>
      </div>
      <div class="footer-bottom">
        <p>&copy; ${new Date().getFullYear()} <span id="footer-copyright-name">${appSettings.shopName}</span>. All rights reserved.</p>
      </div>
    </div>
  `;

  window.addEventListener("settingsLoaded", (e) => {
    const brandHtml = formatBrandHtml(e.detail.shopName);
    // Update navbar brand
    const navBrand = document.getElementById("nav-brand-link");
    if (navBrand) navBrand.innerHTML = brandHtml;
    // Update footer brand
    const footerBrand = document.getElementById("footer-brand-text");
    if (footerBrand) footerBrand.innerHTML = brandHtml;
    // Update footer copyright
    const footerCopy = document.getElementById("footer-copyright-name");
    if (footerCopy) footerCopy.textContent = e.detail.shopName;
    // Update page title
    const titleParts = document.title.split("\u2014");
    if (titleParts.length > 1) {
      document.title = e.detail.shopName + " \u2014" + titleParts.slice(1).join("\u2014");
    } else {
      document.title = e.detail.shopName + " \u2014 " + document.title;
    }
    // Update chat widget
    const chatTitle = document.getElementById("chat-brand-title");
    if (chatTitle) chatTitle.textContent = e.detail.shopName;
    const chatBubble = document.getElementById("chat-widget-bubble");
    if (chatBubble) chatBubble.title = `Chat with ${e.detail.shopName} Support`;
    // Update links
    const link = document.getElementById("footer-wa-link");
    if (link) link.href = `https://wa.me/${e.detail.whatsappNumber}`;
    const igLink = document.getElementById("footer-ig-link");
    if (igLink) igLink.href = `https://instagram.com/${e.detail.instagramId}`;
  });
}

// ─────────────────────────────────────────────────────────
// MOBILE MENU TOGGLE
// ─────────────────────────────────────────────────────────
function setupMobileMenu() {
  document.addEventListener("click", (e) => {
    const toggle = e.target.closest(".menu-toggle");
    const menu = document.getElementById("mobile-menu");
    if (toggle && menu) {
      menu.style.display = menu.style.display === "none" ? "block" : "none";
    }
  });
}

// ─────────────────────────────────────────────────────────
// HELPER — inject FontAwesome if not already present
// ─────────────────────────────────────────────────────────
function injectFontAwesome() {
  if (!document.querySelector('link[href*="font-awesome"]')) {
    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css";
    document.head.appendChild(link);
  }
}

// ─────────────────────────────────────────────────────────
// FLOATING CHAT WIDGET
// ─────────────────────────────────────────────────────────
function initFloatingChatWidget() {
  // Prevent duplicate insertion
  if (document.getElementById("floating-chat-widget-root")) return;

  const wrapper = document.createElement("div");
  wrapper.id = "floating-chat-widget-root";
  wrapper.style.cssText = "position: fixed; bottom: 30px; right: 30px; z-index: 9999; font-family: var(--font-body);";

  // Dynamic CSS style block injection to keep it self-contained
  const styleBlock = document.createElement("style");
  styleBlock.innerHTML = `
    .chat-bubble-btn {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      background: linear-gradient(135deg, var(--accent-gold) 0%, #a27f3c 100%);
      color: #000000;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.6rem;
      cursor: pointer;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4), 0 0 0 0px rgba(201, 164, 85, 0.4);
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      position: relative;
      animation: chatPulse 2s infinite;
    }
    .chat-bubble-btn:hover {
      transform: scale(1.08) rotate(5deg);
      box-shadow: 0 6px 25px rgba(201, 164, 85, 0.5);
    }
    @keyframes chatPulse {
      0% {
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4), 0 0 0 0px rgba(201, 164, 85, 0.5);
      }
      70% {
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4), 0 0 0 12px rgba(201, 164, 85, 0);
      }
      100% {
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4), 0 0 0 0px rgba(201, 164, 85, 0);
      }
    }
    .chat-panel {
      display: none;
      position: absolute;
      bottom: 75px;
      right: 0;
      width: 340px;
      max-width: 90vw;
      background: rgba(18, 18, 18, 0.85);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--glass-border);
      border-radius: var(--radius-md);
      box-shadow: var(--shadow-lg), 0 0 30px rgba(201, 164, 85, 0.05);
      overflow: hidden;
      flex-direction: column;
      animation: panelFadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    @keyframes panelFadeIn {
      from {
        opacity: 0;
        transform: translateY(15px) scale(0.95);
      }
      to {
        opacity: 1;
        transform: translateY(0) scale(1);
      }
    }
    .chat-header {
      background: linear-gradient(to right, #161616, #0e0e0e);
      padding: 1rem 1.2rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid var(--border-color);
    }
    .chat-profile {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .chat-avatar {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      border: 1px solid var(--accent-gold);
      background-color: var(--accent-gold);
      display: flex;
      align-items: center;
      justify-content: center;
      color: #000;
      font-weight: bold;
      font-size: 0.85rem;
    }
    .chat-title-info h5 {
      margin: 0;
      font-family: var(--font-body);
      font-size: 0.85rem;
      font-weight: 600;
      color: var(--text-primary);
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .chat-status-dot {
      width: 8px;
      height: 8px;
      background-color: #2e4d3a;
      border-radius: 50%;
      display: inline-block;
      box-shadow: 0 0 8px #2e4d3a;
    }
    .chat-title-info span {
      font-size: 0.7rem;
      color: var(--text-muted);
      display: block;
    }
    .chat-close-btn {
      color: var(--text-muted);
      cursor: pointer;
      font-size: 1rem;
      transition: var(--transition-fast);
      padding: 4px;
    }
    .chat-close-btn:hover {
      color: var(--accent-gold);
    }
    .chat-body {
      padding: 1.2rem;
      display: flex;
      flex-direction: column;
      gap: 1rem;
      max-height: 300px;
      overflow-y: auto;
    }
    .chat-msg-bubble {
      background-color: var(--bg-secondary);
      border: 1px solid var(--border-color);
      padding: 0.8rem;
      border-radius: var(--radius-sm);
      border-top-left-radius: 0;
      color: var(--text-primary);
      font-size: 0.8rem;
      line-height: 1.4;
      max-width: 85%;
    }
    .chat-action-container {
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-top: 4px;
    }
    .chat-action-chip {
      background: transparent;
      border: 1px solid var(--accent-gold);
      color: var(--accent-gold);
      padding: 0.4rem 0.85rem;
      border-radius: 20px;
      font-size: 0.75rem;
      font-weight: 500;
      cursor: pointer;
      text-align: left;
      transition: var(--transition-fast);
      width: 100%;
    }
    .chat-action-chip:hover {
      background-color: var(--accent-gold);
      color: var(--bg-dark);
      transform: translateY(-1px);
    }
    .chat-footer {
      padding: 0.75rem 1.2rem;
      border-top: 1px solid var(--border-color);
      background-color: rgba(22, 22, 22, 0.5);
      display: flex;
      gap: 8px;
      align-items: center;
    }
    .chat-input-field {
      flex-grow: 1;
      background-color: var(--bg-secondary);
      border: 1px solid var(--border-color);
      color: var(--text-primary);
      border-radius: 20px;
      padding: 0.45rem 1rem;
      font-size: 0.78rem;
      transition: var(--transition-fast);
    }
    .chat-input-field:focus {
      border-color: var(--accent-gold);
    }
    .chat-send-btn {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background-color: var(--accent-gold);
      color: var(--bg-dark);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: var(--transition-fast);
      font-size: 0.8rem;
    }
    .chat-send-btn:hover {
      background-color: var(--accent-gold-hover);
      transform: scale(1.05);
    }
  `;

  document.head.appendChild(styleBlock);

  // Initial markup structure
  wrapper.innerHTML = `
    <!-- Collapsed State Bubble -->
    <div id="chat-widget-bubble" class="chat-bubble-btn" title="Chat with ${appSettings.shopName} Support">
      <i class="fab fa-whatsapp"></i>
    </div>

    <!-- Expanded State Panel -->
    <div id="chat-widget-panel" class="chat-panel">
      <!-- Header -->
      <div class="chat-header">
        <div class="chat-profile">
          <div class="chat-avatar">JB</div>
          <div class="chat-title-info">
            <h5><span id="chat-brand-title">${appSettings.shopName}</span> <span class="chat-status-dot"></span></h5>
            <span>Online | Shopping Buddy</span>
          </div>
        </div>
        <div id="chat-widget-close" class="chat-close-btn">
          <i class="fas fa-xmark"></i>
        </div>
      </div>

      <!-- Body -->
      <div class="chat-body">
        <div class="chat-msg-bubble">
          Hi bestie! I'm your shopping buddy 💜 How can I help you today?
        </div>
        
        <div class="chat-action-container">
          <button class="chat-action-chip" data-intent="find"><i class="fas fa-search"></i> Find an Item</button>
          <button class="chat-action-chip" data-intent="style"><i class="fas fa-wand-magic-sparkles"></i> Style Me for an Occasion</button>
          <button class="chat-action-chip" data-intent="track"><i class="fas fa-box"></i> Track My Order</button>
          <button class="chat-action-chip" data-intent="payment"><i class="fas fa-wallet"></i> UPI Payment Help</button>
          <button class="chat-action-chip" data-intent="chat"><i class="fas fa-comments"></i> Talk to Owner</button>
        </div>
      </div>

      <!-- Footer -->
      <form id="chat-widget-footer-form" class="chat-footer">
        <input type="text" id="chat-widget-input" class="chat-input-field" placeholder="Ask me anything..." required>
        <button type="submit" class="chat-send-btn">
          <i class="fas fa-paper-plane"></i>
        </button>
      </form>
    </div>
  `;

  document.body.appendChild(wrapper);

  // Bind Toggle Handlers
  const bubble = document.getElementById("chat-widget-bubble");
  const panel = document.getElementById("chat-widget-panel");
  const closeBtn = document.getElementById("chat-widget-close");

  bubble.addEventListener("click", () => {
    panel.style.display = "flex";
    bubble.style.display = "none";
  });

  closeBtn.addEventListener("click", () => {
    panel.style.display = "none";
    bubble.style.display = "flex";
  });

  // Bind Quick-Action Pill buttons
  const actions = wrapper.querySelectorAll(".chat-action-chip");
  actions.forEach(btn => {
    btn.addEventListener("click", () => {
      const intent = btn.getAttribute("data-intent");
      triggerHandoff(intent, "");
    });
  });

  // Bind Footer Text form submission
  const footerForm = document.getElementById("chat-widget-footer-form");
  const inputEl = document.getElementById("chat-widget-input");
  footerForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const val = inputEl.value.trim();
    if (val) {
      triggerHandoff("custom", val);
      inputEl.value = "";
    }
  });

  // Main handoff redirect logic
  function triggerHandoff(intent, customMessage) {
    let text = "";
    let useWhatsApp = true; // default route

    switch (intent) {
      case "find":
        text = "Hello! I am looking for a specific item in your store catalog.";
        useWhatsApp = true;
        break;
      case "style":
        text = `Hi! I would love some styling recommendations for an upcoming occasion from ${appSettings.shopName}.`;
        useWhatsApp = false; // redirect to Instagram DM
        break;
      case "track":
        text = `Hello! I would like to track my ${appSettings.shopName} order.`;
        useWhatsApp = true;
        break;
      case "payment":
        text = "Hi, I need help with making a payment or verified UPI UTR submission for my order.";
        useWhatsApp = true;
        break;
      case "chat":
        text = `Hello ${appSettings.shopName}! I want to chat about a custom request.`;
        useWhatsApp = true;
        break;
      case "custom":
        text = customMessage;
        useWhatsApp = true;
        break;
    }

    if (useWhatsApp) {
      const encoded = encodeURIComponent(text);
      const waUrl = `https://wa.me/${appSettings.whatsappNumber}?text=${encoded}`;
      window.open(waUrl, "_blank");
    } else {
      // Instagram route: copy text and open messages
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => {
          alert("Sizing request message copied to clipboard!\n\nRedirecting you to Instagram to paste and message us.");
          window.open(`https://ig.me/m/${appSettings.instagramId}`, "_blank");
        }).catch(() => {
          fallbackCopyAndRedirect(text);
        });
      } else {
        fallbackCopyAndRedirect(text);
      }
    }
  }

  function fallbackCopyAndRedirect(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    try {
      document.execCommand('copy');
    } catch (e) {}
    document.body.removeChild(textArea);
    alert("Sizing request message copied to clipboard!\n\nRedirecting you to Instagram to paste and message us.");
    window.open(`https://ig.me/m/${appSettings.instagramId}`, "_blank");
  }
}

// Global Wishlist Management
window.toggleWishlist = (productId, btnEl) => {
  let wishlist = JSON.parse(localStorage.getItem("boutique_wishlist") || "[]");
  const idx = wishlist.indexOf(productId);
  let active = false;
  if (idx > -1) {
    wishlist.splice(idx, 1);
  } else {
    wishlist.push(productId);
    active = true;
  }
  localStorage.setItem("boutique_wishlist", JSON.stringify(wishlist));
  
  if (btnEl) {
    btnEl.classList.toggle("active", active);
    const icon = btnEl.querySelector("i");
    if (icon) {
      icon.classList.toggle("fas", active);
      icon.classList.toggle("far", !active);
    }
  }
  updateWishlistBadge();
  
  // Custom event to let catalog page know a change occurred
  window.dispatchEvent(new CustomEvent("wishlistChanged"));
};

export function updateWishlistBadge() {
  const wishlist = JSON.parse(localStorage.getItem("boutique_wishlist") || "[]");
  const count = wishlist.length;
  document.querySelectorAll(".wishlist-count-badge").forEach(badge => {
    badge.textContent = count;
    badge.style.display = count > 0 ? "flex" : "none";
  });
}

// Swaps the image of a product card when a color swatch is clicked/hovered
window.swapCardImage = (swatchEl) => {
  const siblings = swatchEl.parentNode.querySelectorAll('.swatch-dot');
  siblings.forEach(d => d.classList.remove('active'));
  swatchEl.classList.add('active');
  const card = swatchEl.closest('.product-card');
  if (card) {
    const img = card.querySelector('img.product-img');
    const newSrc = swatchEl.getAttribute('data-img');
    if (img && newSrc) {
      img.src = newSrc;
    }
  }
};

// Maps dynamic boutique color names to standard CSS-compatible color hex codes
window.getColorHex = (color) => {
  if (!color) return "#ccc";
  const normalized = color.toLowerCase().trim();
  const dict = {
    "golden yellow": "#ffd700",
    "gold": "#ffd700",
    "golden": "#ffd700",
    "sage green": "#8fbc8f",
    "sage": "#8fbc8f",
    "noir black": "#1c1c1c",
    "noir": "#1c1c1c",
    "black": "#000000",
    "navy blue": "#000080",
    "navy": "#000080",
    "midnight blue": "#191970",
    "midnight": "#191970",
    "crimson velvet": "#990000",
    "crimson": "#dc2626",
    "warm tan": "#d2b48c",
    "tan": "#d2b48c",
    "onyx black": "#353839",
    "onyx": "#353839",
    "champagne gold": "#f7e7ce",
    "champagne": "#f7e7ce",
    "ivory": "#fffff0",
    "sandy beige": "#f5f5dc",
    "beige": "#f5f5dc",
    "rose gold": "#b76e79",
    "rose": "#ff007f",
    "ocean blue": "#0077be",
    "ocean": "#0077be",
    "emerald green": "#50c878",
    "emerald": "#50c878",
    "olive green": "#808000",
    "olive": "#808000",
    "forest green": "#228b22",
    "forest": "#228b22",
    "white": "#ffffff"
  };

  if (dict[normalized]) return dict[normalized];
  if (normalized.startsWith("#") || normalized.startsWith("rgb") || normalized.startsWith("hsl")) {
    return color;
  }
  const words = normalized.split(" ");
  for (let w of words) {
    if (dict[w]) return dict[w];
  }
  return normalized.replace(/\s+/g, "");
};

export { appSettings };
