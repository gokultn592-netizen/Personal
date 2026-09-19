'use client';

import { useState, useRef, useEffect } from 'react';
import { Suspense } from 'react';
import ParallaxBackground from '@/components/ParallaxBackground';
import dynamic from 'next/dynamic';
const SceneCanvas = dynamic(() => import('@/components/scene/SceneCanvas'), { ssr: false });
import Controls from '@/components/hud/Controls';
import Telemetry from '@/components/hud/Telemetry';
import SolutionShelf from '@/components/hud/SolutionShelf';
import useNQueensStream from '@/hooks/useNQueensStream';
import { useMemeAudio } from '@/hooks/useMemeAudio';

export default function HomePage() {
  const {
    events,
    currentEvent,
    currentEventIndex,
    n,
    setN,
    isPlaying,
    play,
    pause,
    reset,
    stepNext,
    speedMs,
    setSpeedMs,
    playbackStatus,
    jumpToEventIndex,
  } = useNQueensStream(4);

  // Stealth meme audio listener (vazhthukkal.mp3 / failure.mp3)
  useMemeAudio(currentEvent, playbackStatus, events);

  const mainRef = useRef<HTMLDivElement>(null);
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });

  // Mouse-driven parallax
  useEffect(() => {
    const onMouseMove = (e: MouseEvent) => {
      const cx = window.innerWidth / 2;
      const cy = window.innerHeight / 2;
      setMousePos({
        x: (e.clientX - cx) / cx,
        y: (e.clientY - cy) / cy,
      });
    };
    window.addEventListener('mousemove', onMouseMove, { passive: true });
    return () => window.removeEventListener('mousemove', onMouseMove);
  }, []);

  const parallaxTransform = `translate(${mousePos.x * -15}px, ${mousePos.y * -10}px)`;

  return (
    <div ref={mainRef} className="relative w-full h-screen overflow-hidden bg-slate-950" suppressHydrationWarning>
      {/* 2D CSS Parallax Background */}
      <div style={{ transform: parallaxTransform }} className="absolute inset-0 transition-transform duration-300 ease-out">
        <ParallaxBackground />
      </div>

      {/* Top header */}
      <header className="absolute top-0 left-0 right-0 z-30 px-6 py-4 flex items-center justify-between pointer-events-none">
        <div className="pointer-events-auto">
          <h1 className="text-2xl md:text-3xl font-black tracking-tighter bg-gradient-to-r from-cyan-300 via-blue-300 to-cyan-400 bg-clip-text text-transparent">
            N-QUEENS
          </h1>
          <p className="text-[10px] text-cyan-600/80 font-mono tracking-[0.3em] uppercase">
            Tactical Backtracking Visualizer
          </p>
        </div>
        <div className="pointer-events-auto hidden md:block">
          <div className="text-right">
            <div className="text-xs text-cyan-400/60 font-mono">FASTAPI SSE STREAM</div>
            <div className="text-sm font-mono text-slate-400">localhost:8000</div>
          </div>
        </div>
      </header>

      {/* Main 3D Canvas */}
      <main className="absolute inset-0 z-0">
        <Suspense fallback={<div className="w-full h-full flex items-center justify-center text-cyan-400/30 font-mono text-sm">Loading 3D Scene...</div>}>
          <SceneCanvas events={events} currentEventIndex={currentEventIndex} n={n} />
        </Suspense>
      </main>

      {/* HUD Overlays */}
      <aside className="absolute top-20 left-4 md:left-6 z-20 flex flex-col gap-4 pointer-events-none">
        <div className="pointer-events-auto">
          <Controls
            n={n}
            setN={setN}
            speedMs={speedMs}
            setSpeedMs={setSpeedMs}
            isPlaying={isPlaying}
            play={play}
            pause={pause}
            reset={reset}
            stepNext={stepNext}
          />
        </div>
        <div className="pointer-events-auto">
          <Telemetry
            events={events}
            currentEventIndex={currentEventIndex}
            currentEvent={currentEvent}
          />
        </div>
      </aside>

      {/* Bottom Solution Shelf */}
      <aside className="absolute bottom-4 left-4 right-4 md:left-auto md:right-6 md:max-w-md z-20 pointer-events-none">
        <div className="pointer-events-auto">
          <SolutionShelf
            events={events}
            currentEventIndex={currentEventIndex}
            onSelectSolution={jumpToEventIndex}
          />
        </div>
      </aside>

      {/* Status indicator */}
      <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-30 pointer-events-none">
        <div className="flex items-center gap-2 px-4 py-1.5 rounded-full bg-slate-900/70 backdrop-blur-md border border-cyan-500/20 shadow-lg shadow-cyan-900/10">
          <span className={`w-2 h-2 rounded-full ${isPlaying ? 'bg-emerald-400 animate-pulse' : playbackStatus === 'FINISHED' ? 'bg-cyan-400' : 'bg-amber-400'}`} />
          <span className="text-xs font-mono text-slate-300">
            {isPlaying ? 'STREAM ACTIVE' : playbackStatus === 'FINISHED' ? 'SEARCH COMPLETE' : 'PAUSED'}
          </span>
          <span className="text-slate-600 mx-1">|</span>
          <span className="text-xs font-mono text-cyan-500">N={n}</span>
          <span className="text-xs font-mono text-cyan-400">{currentEventIndex} steps</span>
        </div>
      </div>
    </div>
  );
}
