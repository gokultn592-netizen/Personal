'use client';

import React, { Suspense, useRef, useState, useEffect } from 'react';
import { useGLTF, useAnimations } from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

function MechModel({
  position,
  row,
  eventType,
  isThalaivarMode,
}: {
  position: [number, number, number];
  row: number;
  eventType: string;
  isThalaivarMode: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const auraRingRef = useRef<THREE.Mesh>(null);
  const { scene, animations } = useGLTF('/models/mech.gltf');
  const { actions } = useAnimations(animations, group);

  const [animName, setAnimName] = useState<string>('Idle');
  const targetPosRef = useRef<[number, number, number]>(position);
  targetPosRef.current = position;

  const prevRowRef = useRef<number | null>(null);

  useEffect(() => {
    if (group.current && prevRowRef.current !== null && prevRowRef.current !== row) {
      // Instant snap when transitioning across rows to eliminate overlap duplication with placed queen
      const [tx, ty, tz] = position;
      group.current.position.x = tx;
      group.current.position.y = ty;
      group.current.position.z = tz;
    }
    prevRowRef.current = row;
  }, [row, position]);

  useFrame((state, delta) => {
    if (!group.current) return;

    if (isThalaivarMode && auraRingRef.current) {
      auraRingRef.current.rotation.z += delta * 1.5;
    }

    const [tx, ty, tz] = targetPosRef.current;
    const cx = group.current.position.x;
    const cz = group.current.position.z;

    const dx = tx - cx;
    const dz = tz - cz;
    const dist = Math.sqrt(dx * dx + dz * dz);

    if (dist > 0.06) {
      // Measured walking movement across tiles
      const speed = Math.min(1.0, delta * 2.8);
      group.current.position.x += dx * speed;
      group.current.position.z += dz * speed;

      // Rotate smoothly to face direction of movement
      const angle = Math.atan2(dx, dz);
      group.current.rotation.y = angle;

      if (animName !== 'Walk') {
        setAnimName('Walk');
      }
    } else {
      // Arrived at target block
      group.current.position.x = tx;
      group.current.position.z = tz;
      group.current.position.y = ty;

      let nextAnim = 'Hello';
      if (eventType === 'CONFLICT' || eventType === 'REMOVE_BEACON' || eventType === 'COMPLETE') {
        nextAnim = 'Death';
      } else if (eventType === 'SOLUTION_FOUND') {
        nextAnim = 'Dance';
      } else {
        nextAnim = 'Hello';
      }

      if (animName !== nextAnim) {
        setAnimName(nextAnim);
      }
    }
  });

  // Cross-fade animation transitions with measured time scales
  useEffect(() => {
    const act = actions[animName] || actions['Idle'];
    if (act) {
      if (animName === 'Walk') {
        act.setEffectiveTimeScale(0.85);
      } else if (animName === 'Hello') {
        act.setEffectiveTimeScale(0.65);
      } else if (animName === 'Death') {
        act.setEffectiveTimeScale(0.60);
      } else if (animName === 'Dance') {
        act.setEffectiveTimeScale(0.75);
      }

      act.reset().fadeIn(0.3).play();
    }
    return () => {
      if (act) act.fadeOut(0.3);
    };
  }, [animName, actions]);

  return (
    <group ref={group} position={position}>
      {/* Robot character slightly enlarged to 0.22 scale */}
      <primitive object={scene} scale={[0.22, 0.22, 0.22]} />

      {/* Secret Golden Aura when code=Thalaivar is active */}
      {isThalaivarMode && (
        <group>
          <mesh ref={auraRingRef} position={[0, 0.02, 0]} rotation={[-Math.PI / 2, 0, 0]}>
            <ringGeometry args={[0.25, 0.65, 32]} />
            <meshStandardMaterial
              color="#fbbf24"
              emissive="#f59e0b"
              emissiveIntensity={2.0}
              transparent
              opacity={0.85}
              side={THREE.DoubleSide}
            />
          </mesh>
          <pointLight position={[0, 0.8, 0]} color="#fbbf24" intensity={2.5} distance={3.5} />
        </group>
      )}
    </group>
  );
}

function FallbackBox({ position, eventType }: { position: [number, number, number]; eventType: string }) {
  const meshRef = useRef<THREE.Group>(null);

  useFrame((state, delta) => {
    if (!meshRef.current) return;
    if (eventType === 'SOLUTION_FOUND' || eventType === 'COMPLETE') {
      meshRef.current.rotation.y += delta * 2;
    }
  });

  return (
    <group ref={meshRef} position={position}>
      <mesh position={[0, 0.35, 0]}>
        <cylinderGeometry args={[0.16, 0.24, 0.6, 16]} />
        <meshStandardMaterial color="#06b6d4" emissive="#22d3ee" emissiveIntensity={0.8} roughness={0.2} metalness={0.8} />
      </mesh>
      <mesh position={[0, 0.75, 0]}>
        <sphereGeometry args={[0.16, 16, 16]} />
        <meshStandardMaterial color="#a5f3fc" emissive="#00ffff" emissiveIntensity={1.5} />
      </mesh>
      <pointLight position={[0, 0.7, 0]} intensity={1.5} distance={2.5} color="#00ffff" />
    </group>
  );
}

interface MechUnitProps {
  row?: number;
  col?: number;
  n?: number;
  tileSize?: number;
  eventType?: string;
  active?: boolean;
}

export default function MechUnit({
  row = 0,
  col = 0,
  n = 4,
  tileSize = 1.8,
  eventType = 'MOVE_TRY',
}: MechUnitProps) {
  const [isThalaivarMode, setIsThalaivarMode] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search);
      setIsThalaivarMode(params.get('code')?.toLowerCase() === 'thalaivar');
    }
  }, []);

  const offset = -n * tileSize / 2 + tileSize / 2;
  const x = offset + col * tileSize;
  const z = offset + row * tileSize;
  const position: [number, number, number] = [x, 0.06, z];

  return (
    <Suspense fallback={<FallbackBox position={position} eventType={eventType} />}>
      <MechModel
        position={position}
        row={row}
        eventType={eventType}
        isThalaivarMode={isThalaivarMode}
      />
    </Suspense>
  );
}

useGLTF.preload('/models/mech.gltf');
