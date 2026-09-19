'use client';

import { Play, Pause, RotateCcw, StepForward } from 'lucide-react';

interface ControlsProps {
  n: number;
  setN: (n: number) => void;
  speedMs: number;
  setSpeedMs: (ms: number) => void;
  isPlaying: boolean;
  play: () => void;
  pause: () => void;
  reset: () => void;
  stepNext: () => void;
}

export default function Controls({
  n,
  setN,
  speedMs,
  setSpeedMs,
  isPlaying,
  play,
  pause,
  reset,
  stepNext,
}: ControlsProps) {
  const speedLabel = speedMs >= 2000 ? 'Slow' : speedMs >= 1000 ? 'Medium' : 'Fast';

  return (
    <div className="relative z-20 bg-slate-900/85 backdrop-blur-md border border-cyan-500/30 rounded-xl p-3.5 shadow-2xl shadow-cyan-900/20 w-72">
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-cyan-300 font-bold text-sm tracking-wider flex items-center gap-1.5">
          <span className="w-1.5 h-1.5 rounded-full bg-cyan-400 animate-pulse" />
          TACTICAL COMMAND
        </h2>
        <span className="text-[9px] font-mono font-bold bg-cyan-950/80 border border-cyan-500/40 text-cyan-300 px-2 py-0.5 rounded-full uppercase">
          {speedLabel}
        </span>
      </div>

      {/* N Slider */}
      <div className="mb-4">
        <label className="text-slate-300 text-xs font-medium mb-1.5 block">
          Board Size (N): <span className="text-cyan-300 font-mono font-bold">{n}</span>
        </label>
        <input
          type="range"
          min={4}
          max={10}
          step={1}
          value={n}
          onChange={(e) => setN(Number(e.target.value))}
          className="w-full h-1.5 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-cyan-400 hover:accent-cyan-300 transition-colors"
        />
        <div className="flex justify-between text-[10px] text-slate-500 mt-0.5 font-mono">
          <span>4</span>
          <span>7</span>
          <span>10</span>
        </div>
      </div>

      {/* Speed Slider */}
      <div className="mb-4">
        <label className="text-slate-300 text-xs font-medium mb-1.5 flex items-center justify-between">
          <span>Step Delay:</span>
          <span className="text-cyan-300 font-bold">{speedLabel}</span>
        </label>
        <input
          type="range"
          min={300}
          max={3000}
          step={100}
          value={speedMs}
          onChange={(e) => setSpeedMs(Number(e.target.value))}
          className="w-full h-1.5 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-cyan-400 hover:accent-cyan-300 transition-colors"
        />
        <div className="flex justify-between text-[10px] text-slate-400 mt-0.5 font-medium">
          <span>Fast</span>
          <span>Medium</span>
          <span>Slow</span>
        </div>
      </div>

      {/* Control Buttons */}
      <div className="grid grid-cols-4 gap-1.5">
        <button
          onClick={() => {
            console.log("[HUD] Play/Pause clicked for N =", n);
            isPlaying ? pause() : play();
          }}
          className="flex items-center justify-center gap-1.5 px-2.5 py-2.5 rounded-lg bg-cyan-600/20 hover:bg-cyan-500/20 border border-cyan-500/30 text-cyan-300 hover:text-cyan-200 transition-all active:scale-95"
          title={isPlaying ? 'Pause' : 'Play'}
        >
          {isPlaying ? <Pause size={18} /> : <Play size={18} />}
        </button>
        <button
          onClick={stepNext}
          className="flex items-center justify-center px-2.5 py-2.5 rounded-lg bg-slate-700/60 hover:bg-slate-600/60 border border-slate-600/30 text-slate-300 hover:text-white transition-all active:scale-95"
          title="Step"
        >
          <StepForward size={18} />
        </button>
        <button
          onClick={reset}
          className="flex items-center justify-center gap-1.5 px-2.5 py-2.5 rounded-lg bg-slate-700/60 hover:bg-red-900/30 hover:text-red-300 border border-slate-600/30 text-slate-300 transition-all active:scale-95 col-span-2"
          title="Reset"
        >
          <RotateCcw size={16} />
          <span className="text-xs font-medium">RESET</span>
        </button>
      </div>
    </div>
  );
}
