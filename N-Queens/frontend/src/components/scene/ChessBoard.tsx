'use client';

import { MeshStandardMaterial, BoxGeometry, Color } from 'three';
import { useMemo } from 'react';

interface ChessBoardProps {
  n: number;
  highlightCell?: { row: number; col: number } | null;
  tileSize?: number;
}

export function ChessBoard({ n, highlightCell, tileSize = 1.8 }: ChessBoardProps) {
  const boardSize = n * tileSize;
  const offset = -boardSize / 2 + tileSize / 2;

  const darkMaterial = useMemo(
    () => new MeshStandardMaterial({
      color: new Color('#1e293b'),
      roughness: 0.3,
      metalness: 0.4,
    }),
    []
  );

  const lightMaterial = useMemo(
    () => new MeshStandardMaterial({
      color: new Color('#334155'),
      roughness: 0.25,
      metalness: 0.5,
    }),
    []
  );

  const highlightMaterial = useMemo(
    () => new MeshStandardMaterial({
      color: new Color('#22d3ee'),
      roughness: 0.1,
      metalness: 0.9,
      emissive: new Color('#06b6d4'),
      emissiveIntensity: 0.8,
      transparent: true,
      opacity: 0.8,
    }),
    []
  );

  const geometry = useMemo(() => new BoxGeometry(tileSize * 0.96, 0.12, tileSize * 0.96), [tileSize]);

  return (
    <group>
      {Array.from({ length: n }, (_, row) =>
        Array.from({ length: n }, (_, col) => {
          const isDark = (row + col) % 2 === 0;
          const isHighlighted = highlightCell?.row === row && highlightCell?.col === col;
          const x = offset + col * tileSize;
          const z = offset + row * tileSize;

          return (
            <mesh
              key={`${row}-${col}`}
              geometry={geometry}
              material={isHighlighted ? highlightMaterial : isDark ? darkMaterial : lightMaterial}
              position={[x, 0, z]}
              receiveShadow
              castShadow
            />
          );
        })
      )}

      {/* Board outer border & frame */}
      <mesh
        geometry={new BoxGeometry(boardSize + 0.6, 0.18, boardSize + 0.6)}
        material={new MeshStandardMaterial({ color: '#0f172a', roughness: 0.2, metalness: 0.8 })}
        position={[0, -0.15, 0]}
        receiveShadow
      />
      <mesh
        geometry={new BoxGeometry(boardSize + 0.6, 0.18, 0.15)}
        material={new MeshStandardMaterial({ color: '#1e293b', roughness: 0.2, metalness: 0.7 })}
        position={[0, -0.03, -boardSize / 2 - 0.3]}
        receiveShadow
      />
      <mesh
        geometry={new BoxGeometry(boardSize + 0.6, 0.18, 0.15)}
        material={new MeshStandardMaterial({ color: '#1e293b', roughness: 0.2, metalness: 0.7 })}
        position={[0, -0.03, boardSize / 2 + 0.3]}
        receiveShadow
      />
      <mesh
        geometry={new BoxGeometry(0.15, 0.18, boardSize + 0.6)}
        material={new MeshStandardMaterial({ color: '#1e293b', roughness: 0.2, metalness: 0.7 })}
        position={[-boardSize / 2 - 0.3, -0.03, 0]}
        receiveShadow
      />
      <mesh
        geometry={new BoxGeometry(0.15, 0.18, boardSize + 0.6)}
        material={new MeshStandardMaterial({ color: '#1e293b', roughness: 0.2, metalness: 0.7 })}
        position={[boardSize / 2 + 0.3, -0.03, 0]}
        receiveShadow
      />
    </group>
  );
}