import { LANGUAGES } from "../types/settings";
import type { Settings } from "../types/settings";

export default function LanguageSelector({
  language,
  onChange,
  ariaLabel = "Select language",
}: {
  language: Settings["language"];
  onChange: (value: Settings["language"]) => void;
  ariaLabel?: string;
}) {
  return (
    <div className="relative">
      <select
        value={language}
        aria-label={ariaLabel}
        onChange={(e) => onChange(e.target.value as Settings["language"])}
        className="appearance-none rounded-xl border border-slate-200 bg-white px-4 py-2.5 pr-10 text-sm font-medium text-slate-700 shadow-sm hover:border-slate-300 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 transition-colors cursor-pointer dark:bg-slate-800 dark:text-slate-200 dark:border-slate-700 dark:hover:border-slate-600"
      >
        {Object.entries(LANGUAGES).map(([code, label]) => (
          <option key={code} value={code}>
            {label}
          </option>
        ))}
      </select>
      <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-slate-400">
        ▼
      </span>
    </div>
  );
}
