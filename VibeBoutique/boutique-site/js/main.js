import { doc, getDoc } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { db, isConfigured } from "./firebase-config.js";
import { waitForAuthState, resolveRole, signInWithGoogle, signOutUser } from "./auth.js";

// Global state
let appSettings = {
  whatsappNumber: "1234567890",
  shopName: "VibeBoutique",
  instagramId: "vibeboutique"
};

// Shared auth state — set once, used everywhere on the page
export let currentUser = null;
export let currentRole = null;   // "admin" | "buyer" | null

// ─────────────────────────────────────────────────────────
// BOOT — runs on every page
// ─────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", async () => {
  // Always inject FontAwesome so icons are loaded for all pages/users
  injectFontAwesome();

  // 1. Show sign-in gate if user is not authenticated
  const user = await waitForAuthState();

  if (!user) {
    showSignInOverlay();
    return; // Don't render anything else until signed in
  }

  // 2. User is signed in — resolve their role
  currentUser = user;
  currentRole = await resolveRole(user);

  // 3. Render the shared UI
  renderHeader();
  renderFooter();
  updateCartBadge();
  setupMobileMenu();

  // 4. Load Firestore settings if connected
  if (isConfigured) {
    try {
      const settingsSnap = await getDoc(doc(db, "settings", "general"));
      if (settingsSnap.exists()) {
        const data = settingsSnap.data();
        if (data.whatsappNumber) appSettings.whatsappNumber = data.whatsappNumber.replace(/[\s\-\+\(\)]/g, "");
        if (data.shopName) appSettings.shopName = data.shopName;
        if (data.instagramId) appSettings.instagramId = data.instagramId.trim().replace(/@/g, "");
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
        window.dispatchEvent(new CustomEvent("settingsLoaded", { detail: appSettings }));
      } catch (e) {}
    }
  }

  // 5. Notify other scripts that auth + role are ready
  window.dispatchEvent(new CustomEvent("authReady", {
    detail: { user: currentUser, role: currentRole }
  }));
});

// ─────────────────────────────────────────────────────────
// SIGN-IN OVERLAY
// Full-screen gate shown to any visitor who is not signed in
// ─────────────────────────────────────────────────────────
function showSignInOverlay() {
  // Inject FontAwesome first so icons load
  injectFontAwesome();

  const overlay = document.createElement("div");
  overlay.id = "signin-overlay";
  overlay.style.cssText = `
    position: fixed; inset: 0; z-index: 9999;
    background: linear-gradient(135deg, #FAF9F6 0%, #F4F1EA 60%, #E7DECF 100%);
    display: flex; align-items: center; justify-content: center;
    font-family: 'Outfit', sans-serif;
  `;

  overlay.innerHTML = `
    <div style="
      text-align: center;
      max-width: 420px;
      width: 90%;
      padding: 3rem 2.5rem;
      background: rgba(255,255,255,0.7);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(197,168,128,0.3);
      border-radius: 12px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.08);
    ">
      <!-- Logo -->
      <div style="
        font-family: 'Playfair Display', Georgia, serif;
        font-size: 2.2rem;
        font-weight: 600;
        letter-spacing: 0.05em;
        margin-bottom: 0.25rem;
      ">
        VIBE<span style="color: #C5A880;">BOUTIQUE</span>
      </div>

      <p style="color: #6B6860; font-size: 0.9rem; margin-bottom: 2.5rem; letter-spacing: 0.05em;">
        A curated line of premium styles
      </p>

      <!-- Divider -->
      <div style="
        border-top: 1px solid #E2DDD5;
        margin-bottom: 2rem;
        position: relative;
      ">
        <span style="
          position: absolute; top: -0.6rem; left: 50%; transform: translateX(-50%);
          background: rgba(255,255,255,0.9);
          padding: 0 0.75rem;
          font-size: 0.75rem;
          text-transform: uppercase;
          letter-spacing: 0.15em;
          color: #6B6860;
        ">Welcome</span>
      </div>

      <p style="font-size: 1rem; color: #1C1C1C; font-weight: 500; margin-bottom: 1.5rem;">
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
        background: #ffffff;
        border: 1.5px solid #E2DDD5;
        border-radius: 6px;
        font-family: 'Outfit', sans-serif;
        font-size: 0.95rem;
        font-weight: 500;
        color: #1C1C1C;
        cursor: pointer;
        transition: all 0.2s ease;
        box-shadow: 0 2px 8px rgba(0,0,0,0.04);
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

      <p style="margin-top: 2rem; font-size: 0.75rem; color: #6B6860; line-height: 1.6;">
        By signing in you agree to receive order<br>confirmations via WhatsApp.
      </p>
    </div>
  `;

  document.body.appendChild(overlay);

  // Button interaction
  const btn = document.getElementById("google-signin-btn");
  const errEl = document.getElementById("signin-error");

  btn.addEventListener("mouseenter", () => {
    btn.style.borderColor = "#C5A880";
    btn.style.boxShadow = "0 4px 16px rgba(197,168,128,0.2)";
    btn.style.transform = "translateY(-1px)";
  });
  btn.addEventListener("mouseleave", () => {
    btn.style.borderColor = "#E2DDD5";
    btn.style.boxShadow = "0 2px 8px rgba(0,0,0,0.04)";
    btn.style.transform = "translateY(0)";
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
  const avatar = currentUser?.photoURL
    ? `<img src="${currentUser.photoURL}" style="width:32px;height:32px;border-radius:50%;object-fit:cover;border:2px solid var(--accent-gold);" alt="avatar">`
    : `<div style="width:32px;height:32px;border-radius:50%;background:var(--accent-gold);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:0.85rem;color:var(--bg-dark);">${(currentUser?.displayName || currentUser?.email || "?")[0].toUpperCase()}</div>`;

  // Admin portal link — only visible to admins
  const adminNavLink = currentRole === "admin"
    ? `<li><a href="${base}${adminBase}dashboard.html" class="${path.includes("dashboard") ? "active" : ""}">Admin Portal</a></li>`
    : "";

  header.innerHTML = `
    <div class="container navbar">
      <a href="${base}index.html" class="nav-brand">VIBE<span>BOUTIQUE</span></a>
      <nav>
        <ul class="nav-links">
          <li><a href="${base}index.html" class="${(path.endsWith("index.html") || path.endsWith("/")) ? "active" : ""}">Home</a></li>
          <li><a href="${base}shop.html" class="${path.endsWith("shop.html") ? "active" : ""}">Shop</a></li>
          <li><a href="${base}cart.html" class="${path.endsWith("cart.html") ? "active" : ""}">Cart</a></li>
          ${adminNavLink}
        </ul>
      </nav>
      <div class="nav-icons" style="gap: 1rem;">
        <!-- Cart icon -->
        <a href="${base}cart.html" class="nav-icon-btn" aria-label="Cart">
          <i class="fas fa-shopping-bag"></i>
          <span class="cart-count-badge" style="display:none;">0</span>
        </a>
        <!-- User avatar + dropdown -->
        <div class="user-menu-wrapper" style="position:relative;">
          <button id="user-avatar-btn" class="nav-icon-btn" style="padding:0;" aria-label="Account menu">
            ${avatar}
          </button>
          <div id="user-dropdown" style="
            display: none;
            position: absolute; top: calc(100% + 10px); right: 0;
            background: white; border: 1px solid var(--border-color);
            border-radius: var(--radius-md); min-width: 220px;
            box-shadow: var(--shadow-lg); padding: 0.75rem;
            z-index: 200;
          ">
            <div style="padding: 0.5rem 0.5rem 0.75rem; border-bottom: 1px solid var(--border-color); margin-bottom: 0.5rem;">
              <div style="font-weight: 600; font-size: 0.9rem;">${currentUser?.displayName || "Guest"}</div>
              <div style="font-size: 0.75rem; color: var(--text-muted); margin-top: 0.2rem;">${currentUser?.email || ""}</div>
              <div style="font-size: 0.7rem; margin-top: 0.3rem;">
                <span style="
                  display:inline-block; padding: 0.15rem 0.5rem;
                  background: ${currentRole === "admin" ? "#D9EAD3" : "#F4F1EA"};
                  color: ${currentRole === "admin" ? "#38761D" : "#6B6860"};
                  border-radius: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em;
                ">${currentRole === "admin" ? "Admin" : "Buyer"}</span>
              </div>
            </div>
            <button id="signout-btn" style="
              width: 100%; text-align: left; padding: 0.5rem;
              border-radius: 4px; font-size: 0.85rem; cursor: pointer;
              color: #A34E4E; background: none; border: none;
              display: flex; align-items: center; gap: 0.5rem;
              transition: background 0.15s;
            ">
              <i class="fas fa-arrow-right-from-bracket"></i> Sign out
            </button>
          </div>
        </div>
        <!-- Mobile hamburger -->
        <button class="nav-icon-btn menu-toggle" aria-label="Toggle Menu">
          <i class="fas fa-bars"></i>
        </button>
      </div>
    </div>
    <!-- Mobile menu -->
    <div id="mobile-menu" style="display:none; background:var(--bg-secondary); border-bottom:1px solid var(--border-color); padding: var(--spacing-sm) var(--spacing-md);">
      <ul style="list-style:none; display:flex; flex-direction:column; gap:var(--spacing-sm);">
        <li><a href="${base}index.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem;">Home</a></li>
        <li><a href="${base}shop.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem;">Shop</a></li>
        <li><a href="${base}cart.html" style="text-transform:uppercase; font-weight:500; font-size:0.9rem;">Cart</a></li>
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
          <div class="footer-brand">VIBE<span>BOUTIQUE</span></div>
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
        <p>&copy; ${new Date().getFullYear()} VibeBoutique. All rights reserved.</p>
      </div>
    </div>
  `;

  window.addEventListener("settingsLoaded", (e) => {
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

export { appSettings };
