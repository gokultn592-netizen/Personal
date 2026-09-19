'use client';

import { Activity, Zap, ShieldCheck } from 'lucide-react';
import type { SSEEvent } from '@/hooks/useNQueensStream';

interface TelemetryProps {
  events: SSEEvent[];
  currentEventIndex: number;
  currentEvent: SSEEvent | null;
}

export default function Telemetry({ events, currentEventIndex, currentEvent }: TelemetryProps) {
  const stepsCount = currentEventIndex;
  const stackDepth = currentEvent?.row != null ? currentEvent.row + 1 : 0;
  const solutionsFound = events.filter(e => e.type === 'SOLUTION_FOUND').length;
  const conflictsCount = events.filter(e => e.type === 'CONFLICT').length;

  return (
    <div className="bg-slate-900/85 backdrop-blur-md border border-cyan-500/20 rounded-xl p-3.5 shadow-xl shadow-cyan-900/10 w-72">
      <h2 className="text-cyan-400 text-[10px] font-bold tracking-[0.2em] mb-3 uppercase">Live Telemetry</h2>

      <div className="grid grid-cols-2 gap-2">
        <TelemetryCard
          label="STEPS"
          value={stepsCount}
          icon={<Activity size={14} />}
          color="cyan"
          sub={`Index: ${currentEventIndex}`}
        />
        <TelemetryCard
          label="DEPTH"
          value={stackDepth}
          icon={<Zap size={14} />}
          color="amber"
          sub={`Row: ${currentEvent?.row ?? '-'}`}
        />
        <TelemetryCard
          label="SOLUTIONS"
          value={solutionsFound}
          icon={<ShieldCheck size={14} />}
          color="emerald"
          sub={`Found: ${solutionsFound}`}
        />
        <TelemetryCard
          label="CONFLICTS"
          value={conflictsCount}
          icon={<Zap size={14} />}
          color="rose"
          sub={`Pruned`}
        />
      </div>

      {/* Current event display */}
      <div className="mt-3 pt-3 border-t border-slate-700/50">
        <div className="text-[10px] text-slate-500 mb-1 font-mono uppercase">Current Event</div>
        <div className="font-mono text-xs text-cyan-300 bg-slate-950/70 rounded-lg px-2.5 py-1.5 border border-slate-800 truncate">
          {currentEvent ? (
            <>
              <span className="text-cyan-400 font-bold">{currentEvent.type}</span>
              {currentEvent.row != null && (
                <span className="ml-2 text-slate-400">r:{currentEvent.row}</span>
              )}
              {currentEvent.col != null && (
                <span className="ml-1 text-slate-400">c:{currentEvent.col}</span>
              )}
            </>
          ) : (
            <span className="text-slate-600">— idle —</span>
          )}
        </div>
      </div>
    </div>
  );
}

function TelemetryCard({ label, value, icon, color, sub }: { label: string; value: number; icon: React.ReactNode; color: string; sub: string }) {
  const colorMap: Record<string, string> = {
    cyan: 'text-cyan-300 border-cyan-500/20',
    amber: 'text-amber-300 border-amber-500/20',
    emerald: 'text-emerald-300 border-emerald-500/20',
    rose: 'text-rose-300 border-rose-500/20',
  };

  return (
    <div className={`bg-slate-800/40 rounded-lg p-2.5 border ${colorMap[color] || 'border-cyan-500/20'}`}>
      <div className="flex items-center justify-between mb-0.5">
        <span className="text-[9px] font-bold text-slate-400 tracking-wider">{label}</span>
        <span className={`text-xs ${color === 'cyan' ? 'text-cyan-400' : color === 'amber' ? 'text-amber-400' : color === 'emerald' ? 'text-emerald-400' : 'text-rose-400'}`}>{icon}</span>
      </div>
      <div className="text-xl font-mono font-bold text-white">{value}</div>
      <div className="text-[9px] text-slate-500 font-mono mt-0.5 truncate">{sub}</div>
    </div>
  );
}
