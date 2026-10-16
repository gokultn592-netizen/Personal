import { useEffect, useRef, useCallback } from "react";
import type { Settings } from "../types/settings";
import { STORAGE_KEY } from "../store/localStorage";

export const CHANNEL_NAME = "settings_sync";

export function useSync(
  currentTabId: string,
  onSettingsReceived: (settings: Settings) => void
) {
  const callbackRef = useRef(onSettingsReceived);
  callbackRef.current = onSettingsReceived;

  const myTabIdRef = useRef(currentTabId);
  myTabIdRef.current = currentTabId;

  const channelRef = useRef<BroadcastChannel | null>(null);

  useEffect(() => {
    let channel: BroadcastChannel | null = null;

    if (typeof BroadcastChannel !== "undefined") {
      channel = new BroadcastChannel(CHANNEL_NAME);
      channelRef.current = channel;

      channel.onmessage = (event: MessageEvent<Settings>) => {
        const incoming = event.data;
        if (!incoming || typeof incoming !== "object") return;
        // Ignore echo from this tab
        if (incoming.tabId === myTabIdRef.current) return;
        callbackRef.current(incoming);
      };
    }

    // Storage event fallback for cross-tab synchronization
    const handleStorage = (event: StorageEvent) => {
      if (event.key !== STORAGE_KEY || !event.newValue) return;
      try {
        const incoming = JSON.parse(event.newValue) as Settings;
        if (!incoming || typeof incoming !== "object") return;
        // Ignore echo from this tab
        if (incoming.tabId === myTabIdRef.current) return;
        callbackRef.current(incoming);
      } catch {
        // Ignore invalid storage payloads
      }
    };

    window.addEventListener("storage", handleStorage);

    return () => {
      if (channel) {
        channel.close();
        channelRef.current = null;
      }
      window.removeEventListener("storage", handleStorage);
    };
  }, []);

  const broadcastSettings = useCallback((settings: Settings) => {
    try {
      if (channelRef.current) {
        channelRef.current.postMessage(settings);
      }
    } catch (err) {
      console.warn("BroadcastChannel error:", err);
    }
  }, []);

  return { broadcastSettings };
}
