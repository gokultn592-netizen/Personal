export default function FontSizeSlider({
  fontSize,
  onChange,
  sizeLabel = "Size",
}: {
  fontSize: number;
  onChange: (value: number) => void;
  sizeLabel?: string;
}) {
  return (
    <div className="flex items-center gap-5 w-full max-w-xs">
      <label
        htmlFor="font-size"
        className="text-xs font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500"
      >
        {sizeLabel}
      </label>
      <div className="flex-1 relative">
        <input
          id="font-size"
          type="range"
          min={12}
          max={24}
          step={1}
          value={fontSize}
          onChange={(e) => onChange(Number(e.target.value))}
          className="w-full h-2 bg-gradient-to-r from-indigo-200 to-violet-300 dark:from-indigo-900 dark:to-violet-900 rounded-lg appearance-none cursor-pointer accent-indigo-600"
        />
      </div>
      <span className="text-sm font-mono font-bold text-indigo-600 dark:text-indigo-400 w-10 text-right tabular-nums">
        {fontSize}px
      </span>
    </div>
  );
}
