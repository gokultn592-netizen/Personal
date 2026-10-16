# Multi-Tab Sync Settings Panel

A modern, responsive settings management interface built with React, TypeScript, and Tailwind CSS featuring real-time, zero-latency state synchronization across multiple browser tabs without requiring a backend server or WebSockets.

🌐 **Live Demo**: [https://gokultn592-netizen.github.io/Personal/multi-tab-sync/](https://gokultn592-netizen.github.io/Personal/multi-tab-sync/)

---

## Features

- ⚡ **Instant Multi-Tab Synchronization**: Instant peer-to-peer communication between same-origin tabs using the browser's native `BroadcastChannel` API with a `storage` event fallback.
- 🟢 **Live Sync Status Bar**: Positioned at the top of the settings card, displaying a pulsing green live indicator, current tab ID (first 8 characters of UUID), and dynamic `HH:MM:SS` sync timestamps.
- 🌓 **Theme Toggle**: Smooth light and dark mode switching with immediate DOM synchronization.
- 🌐 **Full Multi-Language Support (i18n)**: Real-time dynamic UI localization across 6 languages:
  - English (en)
  - Français (fr)
  - Español (es)
  - 日本語 (ja)
  - हिन्दी (hi)
  - தமிழ் (ta)
- 🔤 **Text Size Slider**: Live typography scaling with responsive design and tabular readout.
- 🛡️ **Conflict Resolution (Last-Write-Wins)**: High-resolution millisecond timestamps ensure the most recent preference update always wins while safely discarding out-of-order or duplicate messages.
- 🚀 **Zero-Flash Theme Boot (Anti-FOUC)**: Synchronous inline script in `<head>` applies saved theme, font size, and language before React hydrates to prevent visual flickering.
- 💾 **Persistent Storage**: All settings are safely mirrored to `localStorage` so they survive browser refreshes and tab restarts.

---

## Installation & Local Development

### Prerequisites
- Node.js (v18 or higher)
- npm (v9 or higher)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/gokultn592-netizen/Personal.git

# 2. Navigate to the project directory
cd "Personal/Multi tab sync"

# 3. Install dependencies
npm install

# 4. Start the Vite development server
npm run dev
```

Open [http://localhost:5173/](http://localhost:5173/) in **two or more browser tabs side-by-side** to test real-time synchronization.

---

## Project Structure

```
multi-tab-sync/
├── .github/
│   └── workflows/
│       └── deploy.yml           # GitHub Pages automated deployment workflow
├── src/
│   ├── components/
│   │   ├── DarkModeToggle.tsx   # Accessible switch button for theme toggle
│   │   ├── FontSizeSlider.tsx   # Text size range slider with live feedback
│   │   ├── LanguageSelector.tsx # Accessible select dropdown with 6 languages
│   │   └── SyncStatus.tsx       # Live status bar with pulsing dot, tab ID, timestamp
│   ├── hooks/
│   │   ├── useSettings.ts       # Unified settings state manager with StrictMode safety
│   │   └── useSync.ts           # BroadcastChannel & storage event multi-tab synchronization
│   ├── store/
│   │   └── localStorage.ts      # LocalStorage persistence layer
│   ├── types/
│   │   ├── settings.ts          # Settings and language TypeScript interfaces
│   │   └── translations.ts      # Complete translation dictionaries (EN, FR, ES, JA, HI, TA)
│   ├── App.tsx                  # Main settings card layout and view model
│   ├── index.css                # Tailwind directives and design system tokens
│   └── main.tsx                 # React DOM root entry point
├── index.html                   # HTML template with no-flash head script
├── package.json                 # Project dependencies and build scripts
├── postcss.config.js            # PostCSS configuration for Tailwind CSS
├── tailwind.config.js           # Tailwind theme and content configuration
├── tsconfig.json                # TypeScript project configuration
├── tsconfig.node.json           # Vite node configuration with composite build support
└── vite.config.ts               # Vite bundler configuration with GitHub Pages base path
```

---

## How It Works

### 1. Synchronization (BroadcastChannel API + Storage Fallback)
The primary cross-tab transport uses the HTML5 **`BroadcastChannel` API** on the channel `settings_sync`.
- When a user adjusts any preference, the active tab creates an updated settings payload and dispatches it over the channel.
- All other active tabs listening to `settings_sync` receive the message event with sub-millisecond latency.
- If a browser environment restricts `BroadcastChannel` (e.g. strict sandboxing or older engines), a secondary **`window.addEventListener("storage", ...)`** listener automatically handles cross-tab synchronization.

### 2. Conflict Resolution & Echo Cancellation
- **Echo Cancellation**: Each tab generates a unique session `tabId` on mount. Any incoming message where `incoming.tabId === currentTabId` is immediately ignored.
- **Last-Write-Wins (LWW)**: Updates include a `lastUpdated: Date.now()` timestamp. A tab only accepts incoming updates if `incoming.lastUpdated > currentSettings.lastUpdated`, ensuring deterministic state convergence during concurrent updates.

### 3. Persistence
All settings are serialized into JSON and saved under the `multi_tab_settings` key in **`localStorage`**. When a new tab opens, it pre-populates its state from `localStorage` before establishing the broadcast connection.

### 4. No-Flash Theme Initialization
An inline script is placed in `<head>` of `index.html`:
```html
<script>
  (function () {
    try {
      var raw = localStorage.getItem("multi_tab_settings");
      if (raw) {
        var s = JSON.parse(raw);
        if (s.theme === "dark") document.documentElement.classList.add("dark");
        if (s.fontSize) document.documentElement.style.fontSize = s.fontSize + "px";
        if (s.language) document.documentElement.lang = s.language;
      }
    } catch (e) {}
  })();
</script>
```
Because this script executes synchronously before the DOM paints, the correct theme, font size, and language are rendered on the very first frame without any flash of unstyled content (FOUC).

---

## Tech Stack

| Technology | Purpose |
| :--- | :--- |
| **React 18** | Functional component architecture and declarative UI state |
| **TypeScript** | Strict compile-time typing and interface validation |
| **Vite** | Blazing fast build tooling and hot module replacement (HMR) |
| **Tailwind CSS** | Responsive utility styling, dark mode classes, glassmorphism |
| **BroadcastChannel API** | Real-time, same-origin cross-tab message broker |
| **LocalStorage API** | Client-side session and preference persistence |

---

## Build & Deployment

```bash
# Type-check and produce optimized production bundle
npm run build

# Preview the production build locally
npm run preview

# Deploy manually to GitHub Pages gh-pages branch
npm run deploy
```

Continuous Deployment is automated via GitHub Actions on push to `main`.
