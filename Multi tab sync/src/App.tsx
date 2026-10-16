import { useSettings } from "./hooks/useSettings";
import DarkModeToggle from "./components/DarkModeToggle";
import LanguageSelector from "./components/LanguageSelector";
import FontSizeSlider from "./components/FontSizeSlider";
import SyncStatus from "./components/SyncStatus";
import { TRANSLATIONS } from "./types/translations";

export default function App() {
  const { settings, updateSettings, tabId } = useSettings();
  const t = TRANSLATIONS[settings.language] || TRANSLATIONS.en;

  return (
    <div
      className={`min-h-screen w-full transition-colors duration-300 bg-gradient-to-br ${
        settings.theme === "dark"
          ? "from-slate-950 via-slate-900 to-indigo-950 text-slate-100"
          : "from-slate-50 via-blue-50/30 to-rose-50/30 text-slate-900"
      }`}
    >
      {/* GDG-style colored bar */}
      <div className="flex h-1.5 w-full">
        <div className="flex-1 bg-[#4285F4]" />
        <div className="flex-1 bg-[#EA4335]" />
        <div className="flex-1 bg-[#FBBC05]" />
        <div className="flex-1 bg-[#34A853]" />
      </div>

      <main className="max-w-xl mx-auto px-6 py-16 md:py-24">
        {/* Header */}
        <header className="mb-10">
          <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight leading-tight mb-2">
            {t.title}
          </h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 font-medium">
            {t.subtitle}
          </p>
        </header>

        {/* Main card */}
        <section className="rounded-3xl bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl border border-slate-200/60 dark:border-slate-700/40 shadow-2xl shadow-black/5 dark:shadow-black/20 overflow-hidden transition-all">
          {/* Top SyncStatus Bar */}
          <SyncStatus tabId={tabId} lastUpdated={settings.lastUpdated} />

          <div className="divide-y divide-slate-100 dark:divide-slate-700/40">
            {/* Appearance */}
            <div className="p-6 md:p-8 flex items-center justify-between gap-6">
              <div>
                <h2 className="text-sm font-bold uppercase tracking-widest text-slate-400 dark:text-slate-500 mb-0.5">
                  {t.appearance}
                </h2>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  {t.appearanceDesc}
                </p>
              </div>
              <DarkModeToggle
                theme={settings.theme}
                ariaLabel={t.toggleTheme}
                onToggle={() =>
                  updateSettings({
                    theme: settings.theme === "dark" ? "light" : "dark",
                  })
                }
              />
            </div>

            {/* Language */}
            <div className="p-6 md:p-8 flex items-center justify-between gap-6">
              <div>
                <h2 className="text-sm font-bold uppercase tracking-widest text-slate-400 dark:text-slate-500 mb-0.5">
                  {t.language}
                </h2>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  {t.languageDesc}
                </p>
              </div>
              <LanguageSelector
                language={settings.language}
                ariaLabel={t.selectLanguage}
                onChange={(value) => updateSettings({ language: value })}
              />
            </div>

            {/* Text Size */}
            <div className="p-6 md:p-8 flex items-center justify-between gap-6">
              <div>
                <h2 className="text-sm font-bold uppercase tracking-widest text-slate-400 dark:text-slate-500 mb-0.5">
                  {t.textSize}
                </h2>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  {t.textSizeDesc}
                </p>
              </div>
              <FontSizeSlider
                fontSize={settings.fontSize}
                sizeLabel={t.size}
                onChange={(value) => updateSettings({ fontSize: value })}
              />
            </div>
          </div>
        </section>

        {/* Instruction */}
        <section className="mt-8 text-center">
          <p className="text-sm md:text-base text-slate-500 dark:text-slate-400 leading-relaxed">
            {t.instructionPrefix}{" "}
            <span className="font-semibold text-indigo-600 dark:text-indigo-400 mx-1">
              {t.instructionHighlight}
            </span>
            {t.instructionSuffix}
          </p>
        </section>
      </main>
    </div>
  );
}
