import { useState } from "react";

function formatHHMMSS(timestamp: number): string {
  const date = new Date(timestamp);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export default function SyncStatus({
  tabId,
  lastUpdated,
}: {
  tabId: string;
  lastUpdated: number;
}) {
  const [mountedTime] = useState(() => Date.now());
  const effectiveTime = lastUpdated > 0 ? lastUpdated : mountedTime;
  const formattedTime = formatHHMMSS(effectiveTime);
  const shortTabId = tabId.slice(0, 8);

  return (
    <div className="w-full bg-emerald-500/10 dark:bg-emerald-500/15 border-b border-emerald-500/20 px-6 py-3 flex items-center justify-between flex-wrap gap-2 transition-colors">
      <div className="flex items-center gap-2.5">
        <span className="relative flex h-2.5 w-2.5">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
          <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
        </span>
        <span className="text-xs md:text-sm font-semibold text-emerald-800 dark:text-emerald-300 tracking-wide">
          Live Sync Active
        </span>
      </div>

      <div className="flex items-center gap-2 text-xs font-mono text-slate-600 dark:text-slate-300">
        <span
          className="px-2.5 py-1 rounded-md bg-white/80 dark:bg-slate-900/60 border border-emerald-500/15 shadow-sm"
          title={`Full Tab ID: ${tabId}`}
        >
          tab: <span className="font-semibold text-emerald-600 dark:text-emerald-400">{shortTabId}</span>
        </span>
        <span className="px-2.5 py-1 rounded-md bg-white/80 dark:bg-slate-900/60 border border-emerald-500/15 shadow-sm">
          {formattedTime}
        </span>
      </div>
    </div>
  );
}
