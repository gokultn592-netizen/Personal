import React, { useEffect } from 'react';
import { Play, Pause, RotateCcw, SkipBack, SkipForward } from 'lucide-react';

export default function PlaybackControls({
  sequenceLength,
  activeStepIndex,
  setActiveStepIndex,
  isPlaying,
  setIsPlaying,
  playbackSpeed,
  setPlaybackSpeed
}) {
  const totalSteps = sequenceLength > 0 ? sequenceLength - 1 : 0;

  useEffect(() => {
    let timer = null;
    if (isPlaying) {
      timer = setInterval(() => {
        setActiveStepIndex((prev) => {
          if (prev === null || prev >= totalSteps) {
            setIsPlaying(false);
            return totalSteps;
          }
          return prev + 1;
        });
      }, playbackSpeed);
    }
    return () => clearInterval(timer);
  }, [isPlaying, totalSteps, playbackSpeed, setActiveStepIndex, setIsPlaying]);

  const handleTogglePlay = () => {
    if (activeStepIndex >= totalSteps) {
      setActiveStepIndex(0);
    }
    setIsPlaying(!isPlaying);
  };

  const handleReset = () => {
    setIsPlaying(false);
    setActiveStepIndex(null); // full view
  };

  const handleStepBack = () => {
    setIsPlaying(false);
    setActiveStepIndex((prev) => (prev === null || prev <= 0 ? 0 : prev - 1));
  };

  const handleStepForward = () => {
    setIsPlaying(false);
    setActiveStepIndex((prev) => (prev === null ? 1 : Math.min(totalSteps, prev + 1)));
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 flex flex-wrap items-center justify-between gap-4">
      {/* Control Buttons */}
      <div className="flex items-center space-x-2">
        <button
          onClick={handleReset}
          title="Show Complete Trajectory"
          className="p-2 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-lg transition"
        >
          <RotateCcw className="w-4 h-4" />
        </button>

        <button
          onClick={handleStepBack}
          disabled={activeStepIndex === 0}
          title="Step Backward"
          className="p-2 bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-300 hover:text-white rounded-lg transition"
        >
          <SkipBack className="w-4 h-4" />
        </button>

        <button
          onClick={handleTogglePlay}
          className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium text-xs transition shadow-md ${
            isPlaying
              ? 'bg-amber-500 hover:bg-amber-600 text-slate-950 font-bold'
              : 'bg-sky-500 hover:bg-sky-600 text-white font-bold'
          }`}
        >
          {isPlaying ? (
            <>
              <Pause className="w-4 h-4" />
              <span>Pause</span>
            </>
          ) : (
            <>
              <Play className="w-4 h-4" />
              <span>{activeStepIndex === totalSteps ? 'Replay' : 'Play Trajectory'}</span>
            </>
          )}
        </button>

        <button
          onClick={handleStepForward}
          disabled={activeStepIndex === totalSteps}
          title="Step Forward"
          className="p-2 bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-300 hover:text-white rounded-lg transition"
        >
          <SkipForward className="w-4 h-4" />
        </button>
      </div>

      {/* Scrubber Slider */}
      <div className="flex-1 min-w-[200px] flex items-center space-x-3">
        <span className="text-xs text-slate-400 font-mono">
          Step {activeStepIndex === null ? totalSteps : activeStepIndex}/{totalSteps}
        </span>
        <input
          type="range"
          min="0"
          max={totalSteps}
          value={activeStepIndex === null ? totalSteps : activeStepIndex}
          onChange={(e) => {
            setIsPlaying(false);
            setActiveStepIndex(Number(e.target.value));
          }}
          className="w-full accent-sky-500 bg-slate-950 rounded-lg cursor-pointer h-1.5"
        />
      </div>

      {/* Speed Selector */}
      <div className="flex items-center space-x-2 text-xs">
        <span className="text-slate-400">Speed:</span>
        <select
          value={playbackSpeed}
          onChange={(e) => setPlaybackSpeed(Number(e.target.value))}
          className="bg-slate-950 border border-slate-700 text-slate-300 rounded px-2 py-1 text-xs focus:outline-none focus:border-sky-500"
        >
          <option value={1000}>0.5x (1000ms)</option>
          <option value={600}>1.0x (600ms)</option>
          <option value={300}>2.0x (300ms)</option>
          <option value={150}>4.0x (150ms)</option>
        </select>
      </div>
    </div>
  );
}
