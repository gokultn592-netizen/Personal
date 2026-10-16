import type { Settings } from "../types/settings";

export default function DarkModeToggle({
  theme,
  onToggle,
  ariaLabel = "Toggle theme",
}: {
  theme: Settings["theme"];
  onToggle: () => void;
  ariaLabel?: string;
}) {
  const isDark = theme === "dark";

  return (
    <button
      type="button"
      role="switch"
      aria-checked={isDark}
      aria-label={ariaLabel}
      onClick={onToggle}
      className="relative inline-flex h-10 w-20 items-center rounded-full bg-gradient-to-r from-amber-300 to-orange-400 dark:from-indigo-900 dark:to-slate-800 shadow-inner transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
    >
      <span
        className={`absolute left-1 top-1 h-8 w-8 rounded-full bg-white shadow-md flex items-center justify-center transition-transform duration-300 ease-out ${
          isDark ? "translate-x-10" : "translate-x-0"
        }`}
      >
        {isDark ? (
          <span className="text-yellow-300 text-lg leading-none select-none">★</span>
        ) : (
          <span className="text-amber-500 text-lg leading-none select-none">☀</span>
        )}
      </span>
      <span className="sr-only">{ariaLabel}</span>
    </button>
  );
}
