# Multi-Tab Sync Settings Panel

A modern, responsive settings management interface built with React, TypeScript, and Tailwind CSS that features real-time, zero-latency state synchronization across multiple browser tabs.

---

## Installation

Clone the repository and install the dependencies:

```bash
# Navigate to the project directory
cd multi-tab-sync

# Install project dependencies
npm install

# Start the local development server
npm run dev
```

The application will be available at `http://localhost:5173/`. Open the link in multiple tabs side-by-side to see live state synchronization in action.

---

## How It Works

### 1. Synchronization (BroadcastChannel API)
- The application uses the browser's native **`BroadcastChannel` API** (`settings_sync` channel) to enable direct, peer-to-peer communication between all open tabs under the same origin.
- When any setting (theme, language, font size) is modified in one tab, the change is immediately broadcasted to all other active tabs with sub-millisecond latency without requiring a backend server or WebSocket connection.
- A **`window.addEventListener("storage", ...)`** listener acts as a fallback to ensure cross-tab sync even in restrictive browser environments.

### 2. Conflict Resolution (Last-Write-Wins)
- Every preference update attaches a high-resolution `lastUpdated` timestamp (`Date.now()`) and a unique session `tabId`.
- When an incoming update is received:
  - **Echo Cancellation**: Messages originating from the same tab (`incoming.tabId === currentTabId`) are discarded.
  - **Last-Write-Wins (LWW)**: Only messages with a timestamp strictly greater than the tab's current state (`incoming.lastUpdated > current.lastUpdated`) are applied. Older or concurrent conflicting messages are safely dropped.

### 3. Persistence (localStorage)
- Whenever a setting changes, the state is serialized and persisted to **`localStorage`** under the key `multi_tab_settings`.
- When a user closes and reopens the browser or launches a new tab, the stored preferences are retrieved so the user's settings persist across sessions.

### 4. No-Flash Initialization
- To prevent Flash of Unstyled Content (FOUC) or theme flicker before React finishes parsing and hydrating, a lightweight inline script is placed directly in the `<head>` of `index.html`.
- This script reads `localStorage` synchronously and immediately applies:
  - The `dark` class to `document.documentElement`
  - The root font size (`document.documentElement.style.fontSize`)
  - The active language code (`document.documentElement.lang`)
- As a result, the page renders with the user's preferred theme instantly on first paint.

---

## Tech Stack

* **React** (v18) — Component architecture and declarative state management.
* **TypeScript** — Strict type safety, interfaces, and compile-time verification.
* **Vite** — Next-generation frontend build tool and lightning-fast HMR.
* **Tailwind CSS** — Utility-first styling with dark mode and glassmorphic designs.
* **BroadcastChannel API** — Same-origin, cross-tab message bus.
* **localStorage** — Client-side persistent storage.

---

## Build & Deployment

```bash
# Type-check and produce an optimized production build
npm run build

# Preview the production build locally
npm run preview

# Deploy build output to GitHub Pages
npm run deploy
```
