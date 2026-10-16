import type { Settings } from "../types/settings";
import { DEFAULT_SETTINGS } from "../types/settings";

export const STORAGE_KEY = "multi_tab_settings";

export function saveSettings(settings: Settings): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
}

export function loadSettings(): Settings {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return DEFAULT_SETTINGS;
  try {
    const parsed = JSON.parse(raw) as Partial<Settings>;
    return { ...DEFAULT_SETTINGS, ...parsed };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function clearSettings(): void {
  localStorage.removeItem(STORAGE_KEY);
}
