export interface Settings {
  theme: "light" | "dark";
  language: "en" | "fr" | "es" | "ja" | "hi" | "ta";
  fontSize: number;
  lastUpdated: number;
  tabId: string;
}

export const DEFAULT_SETTINGS: Settings = {
  theme: "light",
  language: "en",
  fontSize: 16,
  lastUpdated: 0,
  tabId: "",
};

export const LANGUAGES: Record<string, string> = {
  en: "English",
  fr: "Français",
  es: "Español",
  ja: "日本語",
  hi: "हिन्दी",
  ta: "தமிழ்",
};
