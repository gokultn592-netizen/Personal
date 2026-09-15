import React, { useState, useEffect } from 'react';
import { ArrowRight, Layers, BarChart2, Disc, Compass } from 'lucide-react';
import DiskChart from './components/DiskChart';
import PlaybackControls from './components/PlaybackControls';
import ComparisonView from './components/ComparisonView';
import { simulateDiskScheduling, compareDiskScheduling } from './utils/algorithms';

const ALGORITHMS = ['FCFS', 'SSTF', 'SCAN', 'C-SCAN', 'LOOK', 'C-LOOK'];

export default function App() {
  const [requestsInput, setRequestsInput] = useState('98, 183, 37, 122, 14, 124, 65, 67');
  const [initialHead, setInitialHead] = useState(53);
  const [diskSize, setDiskSize] = useState(200);
  const [direction, setDirection] = useState('left');
  const [selectedAlgo, setSelectedAlgo] = useState('FCFS');
  const [activeTab, setActiveTab] = useState('chart');

  const [result, setResult] = useState(null);
  const [comparisonData, setComparisonData] = useState(null);
  const [error, setError] = useState('');

  const [activeStepIndex, setActiveStepIndex] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState(1000); // default 1x

  // Real-time calculation: runs instantly on any input/algorithm change
  useEffect(() => {
    setError('');
    try {
      const parsedRequests = requestsInput
        .split(',')
        .map((x) => parseInt(x.trim(), 10))
        .filter((x) => !isNaN(x));

      if (parsedRequests.length === 0) {
        throw new Error('Please enter at least one valid cylinder request.');
      }

      const numHead = Number(initialHead);
      const numSize = Number(diskSize);

      for (const r of parsedRequests) {
        if (r < 0 || r >= numSize) {
          throw new Error(`Request ${r} is out of disk bounds (0 to ${numSize - 1}).`);
        }
      }
      if (numHead < 0 || numHead >= numSize) {
        throw new Error(`Initial head position ${numHead} is out of disk bounds.`);
      }

      const data = simulateDiskScheduling({
        requests: parsedRequests,
        initial_head: numHead,
        disk_size: numSize,
        direction,
        algorithm: selectedAlgo
      });

      setResult(data);
      setActiveStepIndex(null);

      const compData = compareDiskScheduling({
        requests: parsedRequests,
        initial_head: numHead,
        disk_size: numSize,
        direction
      });
      setComparisonData(compData);
    } catch (err) {
      setError(err.message);
      setResult(null);
      setComparisonData(null);
    }
  }, [requestsInput, initialHead, diskSize, direction, selectedAlgo]);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4 sm:p-6 md:p-10 font-sans selection:bg-sky-500 selection:text-white">
      <div className="max-w-7xl mx-auto space-y-8">

        {/* Header */}
        <header className="border-b border-slate-800 pb-6 flex flex-wrap items-center justify-between gap-4">
          <div>
            <div className="flex items-center space-x-3">
              <div className="p-2.5 bg-sky-500/10 border border-sky-500/20 rounded-xl text-sky-400">
                <Disc className="w-8 h-8 animate-spin-slow" />
              </div>
              <div>
                <h1 className="text-3xl font-extrabold tracking-tight text-white flex items-center gap-2">
                  Disk Scheduling Simulator
                </h1>
                <p className="text-slate-400 text-sm mt-0.5">
                  Operating System cylinder seek time analyzer & interactive head trajectory visualizer.
                </p>
              </div>
            </div>
          </div>

          <div className="flex bg-slate-900 border border-slate-800 p-1.5 rounded-xl">
            <button
              onClick={() => setActiveTab('chart')}
              className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium text-xs transition ${
                activeTab === 'chart'
                  ? 'bg-sky-500 text-white shadow-md shadow-sky-500/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Layers className="w-4 h-4" />
              <span>Interactive Trace</span>
            </button>
            <button
              onClick={() => setActiveTab('compare')}
              className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium text-xs transition ${
                activeTab === 'compare'
                  ? 'bg-sky-500 text-white shadow-md shadow-sky-500/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <BarChart2 className="w-4 h-4" />
              <span>Compare All Algos</span>
            </button>
          </div>
        </header>

        {/* Algorithm Tabs */}
        <div className="flex flex-wrap gap-2">
          {ALGORITHMS.map((algo) => (
            <button
              key={algo}
              onClick={() => setSelectedAlgo(algo)}
              className={`px-5 py-2.5 rounded-xl font-bold text-sm transition-all duration-200 ${
                selectedAlgo === algo
                  ? 'bg-sky-500 text-white shadow-lg shadow-sky-500/25 scale-[1.02]'
                  : 'bg-slate-900 border border-slate-800 text-slate-400 hover:text-white hover:border-slate-700'
              }`}
            >
              {algo}
            </button>
          ))}
        </div>

        {/* Configuration Controls Grid */}
        <div className="grid grid-cols-1 md:grid-cols-12 gap-4 bg-slate-900/90 border border-slate-800 p-6 rounded-2xl shadow-xl backdrop-blur-md">
          <div className="md:col-span-6">
            <label className="block text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
              Cylinder Request Queue (Comma Separated)
            </label>
            <input
              type="text"
              value={requestsInput}
              onChange={(e) => setRequestsInput(e.target.value)}
              placeholder="e.g. 98, 183, 37, 122, 14, 124, 65, 67"
              className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-4 py-2.5 text-sm text-slate-100 font-mono focus:outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500 transition"
            />
          </div>

          <div className="md:col-span-2">
            <label className="block text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
              Initial Head Position
            </label>
            <input
              type="number"
              value={initialHead}
              onChange={(e) => setInitialHead(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-4 py-2.5 text-sm text-slate-100 font-mono focus:outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500 transition"
            />
          </div>

          <div className="md:col-span-2">
            <label className="block text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
              Total Disk Size
            </label>
            <input
              type="number"
              value={diskSize}
              onChange={(e) => setDiskSize(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-4 py-2.5 text-sm text-slate-100 font-mono focus:outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500 transition"
            />
          </div>

          <div className="md:col-span-2">
            <label className="block text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2 flex items-center gap-1">
              <Compass className="w-3.5 h-3.5 text-sky-400" />
              <span>Direction</span>
            </label>
            <select
              value={direction}
              onChange={(e) => setDirection(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3 py-2.5 text-sm text-slate-100 focus:outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500 transition"
            >
              <option value="left">Towards 0 (Left)</option>
              <option value="right">Towards High (Right)</option>
            </select>
          </div>
        </div>

        {/* Error Alert */}
        {error && (
          <div className="p-4 bg-rose-500/10 border border-rose-500/30 text-rose-300 text-sm rounded-xl font-medium">
            ⚠️ {error}
          </div>
        )}

        {/* Main Content View */}
        {activeTab === 'chart' && result && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2 space-y-5">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-sky-400"></span>
                    Head Movement Trajectory ({result.algorithm})
                  </h2>
                  <p className="text-xs text-slate-400">
                    Cylinder sequence path plotted over time. Direction: <span className="text-sky-300 font-semibold uppercase">{direction}</span>
                  </p>
                </div>
                <span className="text-xs px-3 py-1 bg-slate-800 border border-slate-700 text-slate-300 rounded-lg font-mono">
                  Range: 0 to {diskSize - 1}
                </span>
              </div>

              <PlaybackControls
                sequenceLength={result.sequence.length}
                activeStepIndex={activeStepIndex}
                setActiveStepIndex={setActiveStepIndex}
                isPlaying={isPlaying}
                setIsPlaying={setIsPlaying}
                playbackSpeed={playbackSpeed}
                setPlaybackSpeed={setPlaybackSpeed}
              />

              <DiskChart
                sequence={result.sequence}
                diskSize={Number(diskSize)}
                activeStepIndex={activeStepIndex}
              />
            </div>

            <div className="space-y-5">
              <div className="bg-gradient-to-br from-slate-900 to-slate-950 border border-slate-800 p-6 rounded-2xl shadow-xl relative overflow-hidden">
                <div className="absolute top-0 right-0 w-32 h-32 bg-sky-500/10 rounded-full blur-2xl pointer-events-none"></div>
                <span className="text-xs uppercase font-bold text-slate-400 tracking-wider">
                  Total Seek Movement
                </span>
                <div className="text-5xl font-extrabold text-sky-400 mt-2 font-mono tracking-tight">
                  {result.total_movement}
                  <span className="text-sm font-sans font-normal text-slate-400 ml-2">cylinders</span>
                </div>
                <p className="text-xs text-slate-400 mt-3 border-t border-slate-800/80 pt-3">
                  Average seek distance per request: <span className="font-mono text-slate-200 font-semibold">{(result.total_movement / (result.steps.length || 1)).toFixed(1)}</span> cylinders.
                </p>
              </div>

              <div className="bg-slate-900 border border-slate-800 p-5 rounded-2xl shadow-xl">
                <div className="flex items-center justify-between mb-4 pb-2 border-b border-slate-800">
                  <h3 className="text-sm font-bold text-slate-200">Execution Steps</h3>
                  <span className="text-xs text-slate-400 font-mono">{result.steps.length} transitions</span>
                </div>
                <div className="max-h-[360px] overflow-y-auto space-y-2 pr-2">
                  {result.steps.map((step, idx) => {
                    const isActive = activeStepIndex === idx + 1;
                    return (
                      <div
                        key={idx}
                        onClick={() => {
                          setIsPlaying(false);
                          setActiveStepIndex(idx + 1);
                        }}
                        className={`flex items-center justify-between text-xs p-2.5 rounded-xl border transition cursor-pointer font-mono ${
                          isActive
                            ? 'bg-sky-500/15 border-sky-500/40 text-white'
                            : 'bg-slate-950/60 border-slate-800/80 hover:bg-slate-800/50 text-slate-300'
                        }`}
                      >
                        <span className="text-slate-400 font-sans font-medium text-[11px]">Step {idx + 1}</span>
                        <div className="flex items-center space-x-2 text-slate-200">
                          <span className="text-slate-300">{step.from}</span>
                          <ArrowRight className="w-3.5 h-3.5 text-sky-400" />
                          <span className="font-bold text-sky-400">{step.to}</span>
                        </div>
                        <span className="px-2 py-0.5 bg-slate-800 rounded text-sky-300 font-semibold text-[11px]">
                          +{step.distance}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'compare' && (
          <ComparisonView
            comparisonData={comparisonData}
            selectedAlgo={selectedAlgo}
            onSelectAlgo={(algo) => {
              setSelectedAlgo(algo);
              setActiveTab('chart');
            }}
          />
        )}
      </div>
    </div>
  );
}
