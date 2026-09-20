import { useState, useEffect, useRef, useCallback } from 'react';

export interface SSEEvent {
  type: 'MOVE_TRY' | 'PLACE_BEACON' | 'CONFLICT' | 'REMOVE_BEACON' | 'SOLUTION_FOUND' | 'COMPLETE';
  row?: number;
  col?: number;
  attackerRow?: number;
  attackerCol?: number;
  board?: number[];
}

export interface SolutionItem {
  index: number;
  board: number[];
}

export interface StreamController {
  events: SSEEvent[];
  currentEvent: SSEEvent | null;
  isPlaying: boolean;
  speedMs: number;
  n: number;
  setN: (n: number) => void;
  setSpeedMs: (ms: number) => void;
  play: () => void;
  pause: () => void;
  reset: () => void;
  stepNext: () => void;
  jumpToEventIndex: (index: number) => void;
  currentEventIndex: number;
  currentPosition: { row: number; col: number };
  placedQueens: { row: number; col: number }[];
  conflicts: { attackerRow: number; attackerCol: number; row: number; col: number }[];
  discoveredSolutions: SolutionItem[];
  currentStep: number;
  telemetryDepth: number;
  telemetrySteps: number;
  telemetryConflicts: number;
  playbackStatus: 'IDLE' | 'PLAYING' | 'FINISHED';
}

export default function useNQueensStream(initialN = 4): StreamController {
  const [n, setN] = useState(initialN);
  const [speedMs, setSpeedMs] = useState(1200); // 1.2s default presentation step speed
  const [isPlaying, setIsPlaying] = useState(false);
  const [events, setEvents] = useState<SSEEvent[]>([]);
  const [currentEvent, setCurrentEvent] = useState<SSEEvent | null>(null);
  const [currentEventIndex, setCurrentEventIndex] = useState(0);
  const [currentPosition, setCurrentPosition] = useState({ row: 0, col: 0 });
  const [placedQueens, setPlacedQueens] = useState<{ row: number; col: number }[]>([]);
  const [conflicts, setConflicts] = useState<{ attackerRow: number; attackerCol: number; row: number; col: number }[]>([]);
  const [discoveredSolutions, setDiscoveredSolutions] = useState<SolutionItem[]>([]);
  const [currentStep, setCurrentStep] = useState(0);
  const [telemetryDepth, setTelemetryDepth] = useState(0);
  const [telemetrySteps, setTelemetrySteps] = useState(0);
  const [telemetryConflicts, setTelemetryConflicts] = useState(0);
  const [playbackStatus, setPlaybackStatus] = useState<'IDLE' | 'PLAYING' | 'FINISHED'>('IDLE');

  const eventSourceRef = useRef<EventSource | null>(null);
  const queueRef = useRef<SSEEvent[]>([]);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const isPlayingRef = useRef(isPlaying);
  const speedMsRef = useRef(speedMs);
  const isStreamFinishedRef = useRef(false);

  useEffect(() => { isPlayingRef.current = isPlaying; }, [isPlaying]);
  useEffect(() => { speedMsRef.current = speedMs; }, [speedMs]);

  const dispatchNextEvent = useCallback(() => {
    if (queueRef.current.length === 0) {
      timerRef.current = null;
      if (isStreamFinishedRef.current) {
        setPlaybackStatus('FINISHED');
        setIsPlaying(false);
        isPlayingRef.current = false;
      }
      return false;
    }

    const nextEvent = queueRef.current.shift()!;
    setCurrentEvent(nextEvent);
    setEvents((prev) => [...prev, nextEvent]);
    setCurrentEventIndex((prev) => prev + 1);
    setCurrentStep((prev) => prev + 1);

    // Telemetry updates
    setTelemetrySteps((prev) => prev + 1);

    if (nextEvent.type === 'COMPLETE') {
      isStreamFinishedRef.current = true;
      setPlaybackStatus('FINISHED');
      setIsPlaying(false);
      isPlayingRef.current = false;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
        eventSourceRef.current = null;
      }
      return false;
    }

    // Update derived board state
    if (nextEvent.type === 'MOVE_TRY' && nextEvent.row != null && nextEvent.col != null) {
      setCurrentPosition({ row: nextEvent.row, col: nextEvent.col });
    }
    if (nextEvent.type === 'PLACE_BEACON' && nextEvent.row != null && nextEvent.col != null) {
      setPlacedQueens((prev) => {
        const filtered = prev.filter(p => !(p.row === nextEvent.row && p.col === nextEvent.col));
        return [...filtered, { row: nextEvent.row!, col: nextEvent.col! }];
      });
    }
    if (nextEvent.type === 'REMOVE_BEACON' && nextEvent.row != null && nextEvent.col != null) {
      setPlacedQueens((prev) => prev.filter(p => !(p.row === nextEvent.row && p.col === nextEvent.col)));
    }
    if (nextEvent.type === 'CONFLICT') {
      setConflicts((prev) => [...prev.slice(-2), {
        attackerRow: nextEvent.attackerRow ?? 0,
        attackerCol: nextEvent.attackerCol ?? 0,
        row: nextEvent.row ?? 0,
        col: nextEvent.col ?? 0,
      }]);
      setTelemetryConflicts((prev) => prev + 1);
    }
    if (nextEvent.type === 'SOLUTION_FOUND') {
      if (nextEvent.board) {
        setDiscoveredSolutions((prev) => [...prev, { index: prev.length + 1, board: nextEvent.board! }]);
      }
    }

    return true;
  }, []);

  const tick = useCallback(() => {
    if (!isPlayingRef.current) {
      timerRef.current = null;
      return;
    }
    const processed = dispatchNextEvent();
    if (processed) {
      timerRef.current = setTimeout(tick, speedMsRef.current);
    } else {
      timerRef.current = null;
      if (isStreamFinishedRef.current) {
        setPlaybackStatus('FINISHED');
        setIsPlaying(false);
        isPlayingRef.current = false;
      }
    }
  }, [dispatchNextEvent]);

  useEffect(() => {
    isStreamFinishedRef.current = false;
    queueRef.current = [];
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
    }

    const url = `http://localhost:8000/api/stream-solve/${n}`;
    console.log("[SSE] Connecting to:", url);
    const es = new EventSource(url);
    eventSourceRef.current = es;

    es.onmessage = (e) => {
      try {
        const raw = JSON.parse(e.data);
        queueRef.current.push(raw);
        
        if (raw.type === 'COMPLETE') {
          isStreamFinishedRef.current = true;
          es.close();
          eventSourceRef.current = null;
        }

        if (isPlayingRef.current && !timerRef.current) {
          timerRef.current = setTimeout(tick, speedMsRef.current);
        }
      } catch (err) {
        // Ignore parse errors
      }
    };

    es.onerror = () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
        eventSourceRef.current = null;
      }
    };

    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
        eventSourceRef.current = null;
      }
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };
  }, [n, tick]);

  const play = useCallback(() => {
    if (isStreamFinishedRef.current && queueRef.current.length === 0) {
      console.log("[HUD] Simulation FINISHED. Click RESET to restart.");
      return;
    }
    setIsPlaying(true);
    isPlayingRef.current = true;
    setPlaybackStatus('PLAYING');
    if (!timerRef.current && queueRef.current.length > 0) {
      timerRef.current = setTimeout(tick, speedMsRef.current);
    }
  }, [tick]);

  const pause = useCallback(() => {
    setIsPlaying(false);
    isPlayingRef.current = false;
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const reset = useCallback(() => {
    pause();
    setEvents([]);
    setCurrentEvent(null);
    setCurrentEventIndex(0);
    setCurrentPosition({ row: 0, col: 0 });
    setPlacedQueens([]);
    setConflicts([]);
    setDiscoveredSolutions([]);
    setCurrentStep(0);
    setTelemetryDepth(0);
    setTelemetrySteps(0);
    setTelemetryConflicts(0);
    setPlaybackStatus('IDLE');
    queueRef.current = [];
    isStreamFinishedRef.current = false;

    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
    }
    const url = `http://localhost:8000/api/stream-solve/${n}`;
    const es = new EventSource(url);
    eventSourceRef.current = es;

    es.onmessage = (e) => {
      try {
        const raw = JSON.parse(e.data);
        queueRef.current.push(raw);
        if (raw.type === 'COMPLETE') {
          isStreamFinishedRef.current = true;
          es.close();
          eventSourceRef.current = null;
        }
      } catch {}
    };

    es.onerror = () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
        eventSourceRef.current = null;
      }
    };
  }, [n, pause]);

  const stepNext = useCallback(() => {
    pause();
    dispatchNextEvent();
  }, [pause, dispatchNextEvent]);

  const jumpToEventIndex = useCallback((targetIndex: number) => {
    pause();
    if (targetIndex >= 0 && targetIndex <= events.length) {
      setCurrentEventIndex(targetIndex);
      setCurrentEvent(events[targetIndex - 1] ?? null);
    }
  }, [pause, events]);

  return {
    events,
    currentEvent,
    isPlaying,
    speedMs,
    n,
    setN,
    setSpeedMs,
    play,
    pause,
    reset,
    stepNext,
    jumpToEventIndex,
    currentEventIndex,
    currentPosition,
    placedQueens,
    conflicts,
    discoveredSolutions,
    currentStep,
    telemetryDepth,
    telemetrySteps,
    telemetryConflicts,
    playbackStatus,
  };
}
