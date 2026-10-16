import { useState, useEffect, useCallback, useRef } from "react";
import type { Settings } from "../types/settings";
import { DEFAULT_SETTINGS } from "../types/settings";
import { loadSettings, saveSettings } from "../store/localStorage";
import { useSync } from "./useSync";

export function useSettings() {
  const tabId = useRef(
    typeof crypto !== "undefined" && crypto.randomUUID
      ? crypto.randomUUID()
      : `tab-${Math.random().toString(36).substring(2, 9)}`
  ).current;

  const [settings, setSettings] = useState<Settings>(() => {
    const loaded = loadSettings();
    return { ...DEFAULT_SETTINGS, ...loaded, tabId };
  });

  const settingsRef = useRef(settings);
  settingsRef.current = settings;

  useEffect(() => {
    document.documentElement.classList.toggle("dark", settings.theme === "dark");
    document.documentElement.style.fontSize = `${settings.fontSize}px`;
    document.documentElement.lang = settings.language;
  }, [settings.theme, settings.fontSize, settings.language]);

  const handleIncomingSettings = useCallback(
    (incoming: Settings) => {
      if (incoming.lastUpdated <= settingsRef.current.lastUpdated) return;
      const next: Settings = { ...incoming, tabId };
      saveSettings(next);
      setSettings(next);
    },
    [tabId]
  );

  const { broadcastSettings } = useSync(tabId, handleIncomingSettings);

  const updateSettings = useCallback(
    (partial: Partial<Settings>) => {
      const next: Settings = {
        ...settingsRef.current,
        ...partial,
        lastUpdated: Date.now(),
        tabId,
      };
      saveSettings(next);
      broadcastSettings(next);
      setSettings(next);
    },
    [tabId, broadcastSettings]
  );

  return { settings, updateSettings, tabId };
}
