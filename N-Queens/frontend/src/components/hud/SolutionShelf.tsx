'use client';

import { useMemo } from 'react';
import { Trophy, Bot, CheckCircle2 } from 'lucide-react';
import type { SSEEvent } from '@/hooks/useNQueensStream';

interface SolutionShelfProps {
  events: SSEEvent[];
  currentEventIndex?: number;
  onSelectSolution?: (eventIndex: number) => void;
}

export default function SolutionShelf({
  events,
  currentEventIndex = 0,
  onSelectSolution,
}: SolutionShelfProps) {
  const solutionEntries = useMemo(() => {
    const list: { board: number[]; eventIndex: number }[] = [];
    events.forEach((ev, idx) => {
      if (ev.type === 'SOLUTION_FOUND' && ev.board) {
        list.push({ board: ev.board, eventIndex: idx + 1 });
      }
    });
    return list;
  }, [events]);

  return (
    <div className="bg-slate-900/85 backdrop-blur-md border border-cyan-500/20 rounded-2xl p-4 shadow-xl shadow-cyan-900/10 max-w-md w-full">
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-cyan-400 text-xs font-bold tracking-[0.2em] flex items-center gap-2">
          <Trophy size={14} className="text-amber-400 animate-pulse" />
          DISCOVERED SOLUTIONS
        </h2>
        {solutionEntries.length > 0 && (
          <span className="text-[10px] font-mono text-cyan-300 bg-cyan-950/80 px-2 py-0.5 rounded-full border border-cyan-500/30">
            {solutionEntries.length} Found
          </span>
        )}
      </div>

      {solutionEntries.length === 0 ? (
        <div className="text-slate-500 text-xs italic text-center py-4 bg-slate-950/40 rounded-xl border border-slate-800/60">
          No solutions discovered yet...
          <div className="text-[10px] mt-1 text-slate-600 font-mono">Start the simulation to capture arrangements</div>
        </div>
      ) : (
        <div className="flex flex-wrap gap-2.5 max-h-52 overflow-y-auto pr-1">
          {solutionEntries.map((sol, i) => {
            const isSelected = currentEventIndex === sol.eventIndex;
            return (
              <SolutionCard
                key={`sol-${i}`}
                board={sol.board}
                index={i}
                eventIndex={sol.eventIndex}
                isSelected={isSelected}
                onSelect={() => onSelectSolution?.(sol.eventIndex)}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}

function SolutionCard({
  board,
  index,
  eventIndex,
  isSelected,
  onSelect,
}: {
  board: number[];
  index: number;
  eventIndex: number;
  isSelected: boolean;
  onSelect: () => void;
}) {
  const n = board.length;

  return (
    <button
      onClick={onSelect}
      type="button"
      className={`group relative text-left p-2.5 rounded-xl border transition-all duration-200 cursor-pointer ${
        isSelected
          ? 'bg-cyan-950/60 border-cyan-400 shadow-lg shadow-cyan-500/20 scale-[1.02]'
          : 'bg-slate-800/40 hover:bg-cyan-950/30 border-slate-700/80 hover:border-cyan-500/50 hover:scale-[1.02]'
      }`}
    >
      <div className="flex items-center justify-between mb-1.5 gap-2">
        <div className="flex items-center gap-1.5">
          <span
            className={`text-[9px] font-mono font-bold px-1.5 py-0.5 rounded ${
              isSelected ? 'bg-cyan-400 text-slate-950' : 'bg-cyan-950 text-cyan-400'
            }`}
          >
            #{index + 1}
          </span>
          <span className="text-[10px] font-mono text-slate-300">
            Solution #{index + 1}
          </span>
        </div>
        {isSelected ? (
          <CheckCircle2 size={12} className="text-cyan-400" />
        ) : (
          <Bot size={12} className="text-slate-500 group-hover:text-cyan-400 transition-colors" />
        )}
      </div>

      {/* Mini 2D Chessboard Visual Preview */}
      <div
        className="grid gap-0.5 bg-slate-950/80 p-1 rounded-lg border border-slate-800"
        style={{ gridTemplateColumns: `repeat(${n}, minmax(0, 1fr))` }}
      >
        {Array.from({ length: n }, (_, r) =>
          Array.from({ length: n }, (_, c) => {
            const isQueen = board[r] === c;
            const isDarkTile = (r + c) % 2 === 1;

            return (
              <div
                key={`${r}-${c}`}
                className={`w-3.5 h-3.5 flex items-center justify-center rounded-[2px] transition-colors ${
                  isQueen
                    ? 'bg-cyan-500/30 border border-cyan-400/80 shadow-[0_0_6px_rgba(6,182,212,0.6)]'
                    : isDarkTile
                    ? 'bg-slate-900/90'
                    : 'bg-slate-800/60'
                }`}
              >
                {isQueen && <div className="w-1.5 h-1.5 rounded-full bg-cyan-300 shadow-[0_0_4px_#38bdf8]" />}
              </div>
            );
          })
        )}
      </div>
    </button>
  );
}
