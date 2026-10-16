import type { Settings } from "./settings";

export type LanguageCode = Settings["language"];

export interface Translations {
  title: string;
  subtitle: string;
  liveSync: string;
  tabLabel: string;
  initialSync: string;
  appearance: string;
  appearanceDesc: string;
  toggleTheme: string;
  language: string;
  languageDesc: string;
  selectLanguage: string;
  textSize: string;
  textSizeDesc: string;
  size: string;
  instructionPrefix: string;
  instructionHighlight: string;
  instructionSuffix: string;
}

export const TRANSLATIONS: Record<LanguageCode, Translations> = {
  en: {
    title: "Settings Panel",
    subtitle: "Multi-tab synchronized preferences",
    liveSync: "Live Sync Active",
    tabLabel: "tab",
    initialSync: "Initial",
    appearance: "Appearance",
    appearanceDesc: "Switch between light and dark themes",
    toggleTheme: "Toggle theme",
    language: "Language",
    languageDesc: "Choose your preferred language",
    selectLanguage: "Select language",
    textSize: "Text Size",
    textSizeDesc: "Adjust the base font size for readability",
    size: "Size",
    instructionPrefix: "Open this page in multiple tabs and change any setting —",
    instructionHighlight: "all tabs stay in sync instantly",
    instructionSuffix: ".",
  },
  fr: {
    title: "Panneau de Préférences",
    subtitle: "Préférences synchronisées multi-onglets",
    liveSync: "Synchronisation Active",
    tabLabel: "onglet",
    initialSync: "Initial",
    appearance: "Apparence",
    appearanceDesc: "Basculer entre les thèmes clair et sombre",
    toggleTheme: "Changer de thème",
    language: "Langue",
    languageDesc: "Choisissez votre langue préférée",
    selectLanguage: "Choisir la langue",
    textSize: "Taille du Texte",
    textSizeDesc: "Ajustez la taille de police pour la lisibilité",
    size: "Taille",
    instructionPrefix: "Ouvrez cette page dans plusieurs onglets et modifiez un paramètre —",
    instructionHighlight: "tous les onglets se synchronisent instantanément",
    instructionSuffix: ".",
  },
  es: {
    title: "Panel de Configuración",
    subtitle: "Preferencias sincronizadas entre pestañas",
    liveSync: "Sincronización Activa",
    tabLabel: "pestaña",
    initialSync: "Inicial",
    appearance: "Apariencia",
    appearanceDesc: "Alternar entre temas claro y oscuro",
    toggleTheme: "Cambiar tema",
    language: "Idioma",
    languageDesc: "Selecciona tu idioma preferido",
    selectLanguage: "Seleccionar idioma",
    textSize: "Tamaño de Fuente",
    textSizeDesc: "Ajusta el tamaño de fuente para mejorar la lectura",
    size: "Tamaño",
    instructionPrefix: "Abre esta página en varias pestañas y cambia cualquier ajuste —",
    instructionHighlight: "todas las pestañas se sincronizan al instante",
    instructionSuffix: ".",
  },
  ja: {
    title: "設定パネル",
    subtitle: "複数タブ同期プリファレンス",
    liveSync: "ライブ同期中",
    tabLabel: "タブ",
    initialSync: "初期状態",
    appearance: "外観",
    appearanceDesc: "ライト・ダークテーマを切り替えます",
    toggleTheme: "テーマの切り替え",
    language: "言語",
    languageDesc: "使用する言語を選択してください",
    selectLanguage: "言語を選択",
    textSize: "文字サイズ",
    textSizeDesc: "読みやすさに合わせてフォントサイズを調整します",
    size: "サイズ",
    instructionPrefix: "このページを複数のタブで開き、設定を変更してください —",
    instructionHighlight: "すべてのタブが即座に同期されます",
    instructionSuffix: "。",
  },
  hi: {
    title: "सेटिंग्स पैनल",
    subtitle: "मल्टी-टैब सिंक्रनाइज़्ड प्राथमिकताएं",
    liveSync: "लाइव सिंक सक्रिय",
    tabLabel: "टैब",
    initialSync: "प्रारंभिक",
    appearance: "दिखावट",
    appearanceDesc: "लाइट और डार्क थीम के बीच स्विच करें",
    toggleTheme: "थीम बदलें",
    language: "भाषा",
    languageDesc: "अपनी पसंदीदा भाषा चुनें",
    selectLanguage: "भाषा चुनें",
    textSize: "अक्षर का आकार",
    textSizeDesc: "पठन के लिए फ़ॉन्ट आकार समायोजित करें",
    size: "आकार",
    instructionPrefix: "इस पेज को कई टैब में खोलें और कोई भी सेटिंग बदलें —",
    instructionHighlight: "सभी टैब तुरंत सिंक हो जाएंगे",
    instructionSuffix: "।",
  },
  ta: {
    title: "அமைப்புகள் குழு",
    subtitle: "பல தாவல் ஒத்திசைக்கப்பட்ட விருப்பங்கள்",
    liveSync: "நேரடி ஒத்திசைவு செயல்படுகிறது",
    tabLabel: "தாவல்",
    initialSync: "தொடக்கநிலை",
    appearance: "தோற்றம்",
    appearanceDesc: "ஒளி மற்றும் இருண்ட தீம்களுக்கு இடையே மாறவும்",
    toggleTheme: "தீம் மாற்றவும்",
    language: "மொழி",
    languageDesc: "உங்கள் விருப்ப மொழியைத் தேர்ந்தெடுக்கவும்",
    selectLanguage: "மொழியைத் தேர்ந்தெடு",
    textSize: "உரை அளவு",
    textSizeDesc: "படிக்க எளிதாக எழுத்துரு அளவை மாற்றவும்",
    size: "அளவு",
    instructionPrefix: "இந்த பக்கத்தை பல தாவல்களில் திறந்து அமைப்புகளை மாற்றவும் —",
    instructionHighlight: "அனைத்து தாவல்களும் உடனடியாக ஒத்திசையும்",
    instructionSuffix: ".",
  },
};
