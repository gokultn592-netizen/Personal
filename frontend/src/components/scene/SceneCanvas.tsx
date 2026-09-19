'use client';

import { Canvas } from '@react-three/fiber';
import { OrbitControls, Environment, PerspectiveCamera, Stars } from '@react-three/drei';
import { ChessBoard } from './ChessBoard';
import { BeaconPylon } from './BeaconPylon';
import MechUnit from './MechUnit';
import { useMemo } from 'react';
import type { SSEEvent } from '@/hooks/useNQueensStream';

interface SceneCanvasProps {
  events: SSEEvent[];
  currentEventIndex: number;
  n: number;
}

export default function SceneCanvas({ events, currentEventIndex, n }: SceneCanvasProps) {
  const tileSize = 1.8;

  // Current event being rendered
  const currentEvent = useMemo(() => {
    if (currentEventIndex > 0 && currentEventIndex <= events.length) {
      return events[currentEventIndex - 1];
    }
    return null;
  }, [events, currentEventIndex]);

  // Compute exact board state up to currentEventIndex
  const placedBeacons = useMemo(() => {
    // If current event is SOLUTION_FOUND with board data, use exact solution board formation
    if (currentEvent && currentEvent.type === 'SOLUTION_FOUND' && currentEvent.board) {
      return currentEvent.board.map((col, row) => ({ row, col }));
    }

    const placed: { row: number; col: number }[] = [];
    for (let i = 0; i < currentEventIndex && i < events.length; i++) {
      const ev = events[i];
      if (ev.type === 'PLACE_BEACON' && ev.row != null && ev.col != null) {
        const existsIndex = placed.findIndex(p => p.row === ev.row && p.col === ev.col);
        if (existsIndex >= 0) {
          placed[existsIndex] = { row: ev.row, col: ev.col };
        } else {
          placed.push({ row: ev.row, col: ev.col });
        }
      } else if (ev.type === 'REMOVE_BEACON' && ev.row != null && ev.col != null) {
        const existsIndex = placed.findIndex(p => p.row === ev.row && p.col === ev.col);
        if (existsIndex >= 0) {
          placed.splice(existsIndex, 1);
        }
      }
    }
    return placed;
  }, [events, currentEventIndex, currentEvent]);

  // Mech position (with fallback to last valid position so robot never vanishes on COMPLETE)
  const mechPosition = useMemo(() => {
    if (currentEvent && currentEvent.row != null && currentEvent.col != null) {
      return { row: currentEvent.row, col: currentEvent.col };
    }
    // Fallback: search backwards for last valid position
    for (let i = currentEventIndex - 1; i >= 0; i--) {
      const ev = events[i];
      if (ev && ev.row != null && ev.col != null) {
        return { row: ev.row, col: ev.col };
      }
    }
    return { row: 0, col: 0 };
  }, [currentEvent, events, currentEventIndex]);

  const isCelebrating = useMemo(() => {
    if (!currentEvent) return false;
    return currentEvent.type === 'SOLUTION_FOUND';
  }, [currentEvent]);

  // Dynamic camera distance based on larger board size N
  const cameraDist = Math.max(12, n * 2.2);
  const cameraPosY = Math.max(10, n * 1.8);

  return (
    <div className="w-full h-full relative overflow-hidden bg-slate-950">
      <Canvas
        shadows
        camera={{ position: [0, cameraPosY, cameraDist], fov: 45 }}
      >
        {/* High-visibility 3-Point Light Rig */}
        <ambientLight intensity={1.2} />
        
        {/* Main Key Light with Shadow Map */}
        <directionalLight
          position={[12, 22, 14]}
          intensity={2.2}
          castShadow
          shadow-mapSize-width={2048}
          shadow-mapSize-height={2048}
          shadow-bias={-0.0001}
        />

        {/* Soft Cool Fill Light */}
        <directionalLight
          position={[-12, 16, -12]}
          intensity={1.0}
          color="#93c5fd"
        />

        {/* Tactical Cyan Center Core Light */}
        <pointLight
          position={[0, 8, 0]}
          intensity={3}
          distance={25}
          color="#38bdf8"
        />

        <PerspectiveCamera makeDefault position={[0, cameraPosY, cameraDist]} />
        <OrbitControls enablePan={false} maxPolarAngle={Math.PI / 2 - 0.05} target={[0, 0, 0]} />

        <ChessBoard
          n={n}
          tileSize={tileSize}
          highlightCell={mechPosition ? { row: mechPosition.row, col: mechPosition.col } : null}
        />

        {/* Active inspecting robot unit (hidden during victory celebration to prevent overlap with placed queens) */}
        {mechPosition && !isCelebrating && (
          <MechUnit
            row={mechPosition.row}
            col={mechPosition.col}
            n={n}
            tileSize={tileSize}
            eventType={currentEvent ? currentEvent.type : 'MOVE_TRY'}
            active
          />
        )}

        {/* Placed queen robots (suppressing static placed robot on active inspecting square to eliminate duplicate overlap) */}
        {placedBeacons
          .filter(b => isCelebrating || !(mechPosition && b.row === mechPosition.row && b.col === mechPosition.col))
          .map((b) => (
            <BeaconPylon
              key={`beacon-${b.row}-${b.col}`}
              row={b.row}
              col={b.col}
              n={n}
              tileSize={tileSize}
              isCelebrating={isCelebrating}
              visible
            />
          ))}

        <Environment preset="city" environmentIntensity={0.6} />
        <Stars radius={120} depth={60} count={2500} factor={4} saturation={0.5} fade />
      </Canvas>
    </div>
  );
}
