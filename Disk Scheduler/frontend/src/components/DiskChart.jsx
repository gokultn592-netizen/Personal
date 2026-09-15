import React, { useState } from 'react';

export default function DiskChart({ sequence, diskSize, activeStepIndex = null }) {
  const [hoveredNode, setHoveredNode] = useState(null);

  if (!sequence || sequence.length === 0) return null;

  // Determine active sequence based on playback
  const visibleSequence = activeStepIndex !== null 
    ? sequence.slice(0, activeStepIndex + 1)
    : sequence;

  const width = 850;
  const height = Math.max(380, sequence.length * 48);
  const paddingX = 60;
  const paddingY = 50;

  const getX = (val) => paddingX + (val / (diskSize - 1)) * (width - 2 * paddingX);
  const getY = (idx) => paddingY + idx * ((height - 2 * paddingY) / (sequence.length - 1 || 1));

  // Generate SVG polyline points
  const points = visibleSequence.map((val, idx) => `${getX(val)},${getY(idx)}`).join(' ');

  // Grid tick marks
  const ticks = [0, Math.floor((diskSize - 1) * 0.25), Math.floor((diskSize - 1) * 0.5), Math.floor((diskSize - 1) * 0.75), diskSize - 1];

  return (
    <div className="w-full overflow-x-auto bg-slate-900/90 border border-slate-800 rounded-xl p-5 shadow-2xl backdrop-blur-sm relative">
      {/* Legend & Header Controls */}
      <div className="flex flex-wrap items-center justify-between text-xs mb-4 pb-3 border-b border-slate-800 gap-3">
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-1.5">
            <span className="w-3 h-3 rounded-full bg-emerald-400 inline-block shadow-sm shadow-emerald-400/50"></span>
            <span className="text-slate-300 font-medium">Start Head</span>
          </div>
          <div className="flex items-center space-x-1.5">
            <span className="w-3 h-3 rounded-full bg-sky-400 inline-block shadow-sm shadow-sky-400/50"></span>
            <span className="text-slate-300 font-medium">Cylinder Request</span>
          </div>
          <div className="flex items-center space-x-1.5">
            <span className="w-3 h-3 rounded-full bg-amber-400 inline-block shadow-sm shadow-amber-400/50"></span>
            <span className="text-slate-300 font-medium">Disk Boundary (0 / {diskSize - 1})</span>
          </div>
        </div>

        {activeStepIndex !== null && (
          <div className="text-sky-400 font-mono font-semibold bg-sky-500/10 px-2.5 py-1 rounded border border-sky-500/20">
            Playback: Step {activeStepIndex} of {sequence.length - 1}
          </div>
        )}
      </div>

      <svg viewBox={`0 0 ${width} ${height}`} className="w-full min-w-[700px] h-auto font-sans">
        <defs>
          <linearGradient id="headGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#38bdf8" />
            <stop offset="100%" stopColor="#818cf8" />
          </linearGradient>
          <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>

        {/* Vertical Grid Lines & Cylinder Scale */}
        {ticks.map((tickVal) => {
          const x = getX(tickVal);
          return (
            <g key={`grid-${tickVal}`}>
              <line 
                x1={x} y1={paddingY - 15} 
                x2={x} y2={height - paddingY + 15} 
                stroke="#334155" 
                strokeDasharray="4 4" 
                strokeWidth="1"
              />
              <text 
                x={x} y={paddingY - 25} 
                fill="#94a3b8" 
                fontSize="11" 
                fontWeight="600" 
                textAnchor="middle" 
                className="font-mono"
              >
                Cylinder {tickVal}
              </text>
            </g>
          );
        })}

        {/* Outer Boundary Guidelines */}
        <line x1={getX(0)} y1={paddingY - 15} x2={getX(0)} y2={height - paddingY + 15} stroke="#64748b" strokeWidth="1.5" />
        <line x1={getX(diskSize - 1)} y1={paddingY - 15} x2={getX(diskSize - 1)} y2={height - paddingY + 15} stroke="#64748b" strokeWidth="1.5" />

        {/* Horizontal step reference guides */}
        {sequence.map((_, idx) => (
          <line
            key={`row-${idx}`}
            x1={paddingX - 20}
            y1={getY(idx)}
            x2={width - paddingX + 20}
            y2={getY(idx)}
            stroke="#1e293b"
            strokeWidth="1"
          />
        ))}

        {/* Background Full Trajectory Path (Faded if in playback mode) */}
        {activeStepIndex !== null && (
          <polyline
            fill="none"
            stroke="#334155"
            strokeWidth="1.5"
            strokeDasharray="3 3"
            points={sequence.map((val, idx) => `${getX(val)},${getY(idx)}`).join(' ')}
          />
        )}

        {/* Active Head Movement Trajectory Polyline */}
        {visibleSequence.length > 1 && (
          <polyline
            fill="none"
            stroke="url(#headGradient)"
            strokeWidth="3.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            filter="url(#glow)"
            points={points}
          />
        )}

        {/* Direction Arrows on Trajectory Segments */}
        {visibleSequence.map((val, idx) => {
          if (idx === 0) return null;
          const prevVal = visibleSequence[idx - 1];
          const x1 = getX(prevVal);
          const y1 = getY(idx - 1);
          const x2 = getX(val);
          const y2 = getY(idx);
          const midX = (x1 + x2) / 2;
          const midY = (y1 + y2) / 2;

          return (
            <g key={`arrow-${idx}`} className="opacity-70">
              <circle cx={midX} cy={midY} r="7" fill="#0f172a" stroke="#0284c7" strokeWidth="1.5" />
              <text
                x={midX}
                y={midY + 3.5}
                textAnchor="middle"
                fill="#38bdf8"
                fontSize="10"
                fontWeight="bold"
              >
                {x2 >= x1 ? '→' : '←'}
              </text>
            </g>
          );
        })}

        {/* Nodes / Cylinder Hits */}
        {sequence.map((val, idx) => {
          const cx = getX(val);
          const cy = getY(idx);
          const isStart = idx === 0;
          const isBoundary = val === 0 || val === diskSize - 1;
          const isVisited = activeStepIndex === null || idx <= activeStepIndex;
          const isCurrentActive = activeStepIndex !== null && idx === activeStepIndex;

          return (
            <g 
              key={`node-${idx}`}
              className={`transition-all duration-200 cursor-pointer ${!isVisited ? 'opacity-30' : 'opacity-100'}`}
              onMouseEnter={() => setHoveredNode({ val, idx, isStart, isBoundary })}
              onMouseLeave={() => setHoveredNode(null)}
            >
              {/* Active Pulsing Ring */}
              {isCurrentActive && (
                <circle
                  cx={cx}
                  cy={cy}
                  r={12}
                  fill="none"
                  stroke="#38bdf8"
                  strokeWidth="2"
                  className="animate-ping"
                />
              )}

              {/* Node Outer Circle */}
              <circle
                cx={cx}
                cy={cy}
                r={isStart ? 8 : isBoundary ? 6.5 : 5.5}
                className={
                  isStart
                    ? "fill-emerald-400 stroke-slate-950 stroke-2"
                    : isBoundary
                    ? "fill-amber-400 stroke-slate-950 stroke-2"
                    : "fill-sky-400 stroke-slate-950 stroke-2"
                }
              />

              {/* Step Index Label (Left Side) */}
              <text
                x={paddingX - 35}
                y={cy + 4}
                fill="#64748b"
                fontSize="10"
                fontFamily="monospace"
                textAnchor="end"
              >
                {idx === 0 ? 'START' : `S${idx}`}
              </text>

              {/* Node Cylinder Value Label */}
              <text
                x={cx + (cx > width / 2 ? -14 : 14)}
                y={cy + 4}
                textAnchor={cx > width / 2 ? "end" : "start"}
                fill={isVisited ? "#f8fafc" : "#64748b"}
                fontSize="11"
                fontWeight={isStart || isCurrentActive ? "700" : "500"}
                className="font-mono"
              >
                {val} {isStart ? '(Start)' : isBoundary ? '(Boundary)' : ''}
              </text>
            </g>
          );
        })}
      </svg>

      {/* Node Hover Information Tooltip */}
      {hoveredNode && (
        <div className="mt-3 p-2.5 bg-slate-800/90 border border-slate-700 text-xs rounded-lg flex items-center justify-between text-slate-200">
          <div>
            <span className="font-semibold text-sky-400 font-mono">Cylinder {hoveredNode.val}</span>
            <span className="text-slate-400 ml-2">
              ({hoveredNode.isStart ? 'Initial Head Position' : `Step ${hoveredNode.idx}`})
            </span>
          </div>
          {hoveredNode.idx > 0 && (
            <div className="font-mono text-slate-300">
              Distance from Step {hoveredNode.idx - 1} ({sequence[hoveredNode.idx - 1]}): 
              <span className="text-sky-300 font-bold ml-1">
                {Math.abs(hoveredNode.val - sequence[hoveredNode.idx - 1])} cylinders
              </span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
