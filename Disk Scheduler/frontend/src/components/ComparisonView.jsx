import React from 'react';
import { Trophy, Zap, Activity } from 'lucide-react';

export default function ComparisonView({ comparisonData, selectedAlgo, onSelectAlgo }) {
  if (!comparisonData || Object.keys(comparisonData).length === 0) return null;

  const algos = Object.values(comparisonData);
  const minMovement = Math.min(...algos.map((a) => a.total_movement));
  const maxMovement = Math.max(...algos.map((a) => a.total_movement));

  return (
    <div className="space-y-6">
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 shadow-xl">
        <div className="flex items-center justify-between mb-6 border-b border-slate-800 pb-4">
          <div>
            <h2 className="text-xl font-bold text-white flex items-center gap-2">
              <Activity className="w-5 h-5 text-sky-400" />
              Algorithm Comparison Matrix
            </h2>
            <p className="text-xs text-slate-400 mt-1">
              Side-by-side benchmark of total cylinder movement for the current request queue.
            </p>
          </div>
          <span className="text-xs px-3 py-1 bg-sky-500/10 text-sky-400 rounded-full border border-sky-500/20 font-medium">
            All 6 Algorithms Calculated
          </span>
        </div>

        {/* Bar Chart Comparison */}
        <div className="space-y-4 mb-8">
          {algos.map((item) => {
            const isBest = item.total_movement === minMovement;
            const isSelected = item.algorithm === selectedAlgo;
            const barWidthPercent = Math.max(12, (item.total_movement / maxMovement) * 100);

            return (
              <div
                key={item.algorithm}
                onClick={() => onSelectAlgo(item.algorithm)}
                className={`p-3.5 rounded-lg border transition cursor-pointer ${
                  isSelected
                    ? 'bg-sky-950/40 border-sky-500/50 shadow-md shadow-sky-500/10'
                    : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
                }`}
              >
                <div className="flex items-center justify-between text-xs mb-2">
                  <div className="flex items-center space-x-2 font-semibold text-slate-200">
                    <span className="text-sm">{item.algorithm}</span>
                    {isBest && (
                      <span className="flex items-center space-x-1 text-[10px] bg-emerald-500/15 text-emerald-400 px-2 py-0.5 rounded border border-emerald-500/30">
                        <Trophy className="w-3 h-3 text-emerald-400" />
                        <span>Most Efficient</span>
                      </span>
                    )}
                  </div>
                  <div className="font-mono font-bold text-slate-100">
                    {item.total_movement} <span className="text-slate-400 font-normal">cylinders</span>
                  </div>
                </div>

                {/* Animated Progress Bar */}
                <div className="w-full bg-slate-900 rounded-full h-3.5 p-0.5 overflow-hidden border border-slate-800">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      isBest
                        ? 'bg-gradient-to-r from-emerald-500 to-teal-400 shadow-sm shadow-emerald-500/50'
                        : isSelected
                        ? 'bg-gradient-to-r from-sky-500 to-blue-500'
                        : 'bg-slate-700'
                    }`}
                    style={{ width: `${barWidthPercent}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>

        {/* Detailed Comparison Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-slate-300">
            <thead className="bg-slate-950 text-slate-400 uppercase tracking-wider text-[11px] border-b border-slate-800 font-semibold">
              <tr>
                <th className="py-3 px-4">Algorithm</th>
                <th className="py-3 px-4">Total Seek Distance</th>
                <th className="py-3 px-4">Overhead vs Best</th>
                <th className="py-3 px-4">Total Stops</th>
                <th className="py-3 px-4">Trajectory Path</th>
                <th className="py-3 px-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 font-mono">
              {algos.map((item) => {
                const diff = item.total_movement - minMovement;
                const isBest = item.total_movement === minMovement;

                return (
                  <tr
                    key={item.algorithm}
                    className={`hover:bg-slate-800/40 transition ${
                      item.algorithm === selectedAlgo ? 'bg-sky-950/20' : ''
                    }`}
                  >
                    <td className="py-3 px-4 font-sans font-bold text-slate-100 flex items-center space-x-1.5">
                      <span>{item.algorithm}</span>
                      {isBest && <Zap className="w-3.5 h-3.5 text-emerald-400 fill-emerald-400/30" />}
                    </td>
                    <td className="py-3 px-4 font-bold text-sky-400">
                      {item.total_movement}
                    </td>
                    <td className="py-3 px-4">
                      {isBest ? (
                        <span className="text-emerald-400 font-semibold">0 (Optimal)</span>
                      ) : (
                        <span className="text-rose-400">+{diff} cylinders</span>
                      )}
                    </td>
                    <td className="py-3 px-4 text-slate-300">
                      {item.sequence.length} cylinders
                    </td>
                    <td className="py-3 px-4 text-slate-400 max-w-[200px] truncate" title={item.sequence.join(' → ')}>
                      {item.sequence.join(' → ')}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <button
                        onClick={() => onSelectAlgo(item.algorithm)}
                        className={`px-3 py-1 rounded text-[11px] font-sans font-semibold transition ${
                          item.algorithm === selectedAlgo
                            ? 'bg-sky-500 text-white shadow-sm'
                            : 'bg-slate-800 text-slate-300 hover:text-white hover:bg-slate-700'
                        }`}
                      >
                        {item.algorithm === selectedAlgo ? 'Selected' : 'View Trace'}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
