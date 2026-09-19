'use client';

import React, { Suspense, useRef, useEffect, useState, useMemo } from 'react';
import { useGLTF, useAnimations } from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import { SkeletonUtils } from 'three-stdlib';
import * as THREE from 'three';

function PlacedRobotModel({
  position,
  isCelebrating,
  isThalaivarMode,
}: {
  position: [number, number, number];
  isCelebrating: boolean;
  isThalaivarMode: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const auraRingRef = useRef<THREE.Mesh>(null);
  const { scene, animations } = useGLTF('/models/mech.gltf');

  // SkeletonUtils.clone clones the full GLTF skeleton & node hierarchy so each placed queen robot renders independently
  const clonedScene = useMemo(() => SkeletonUtils.clone(scene), [scene]);
  const { actions } = useAnimations(animations, group);

  useEffect(() => {
    const targetAnim = isCelebrating ? 'Dance' : 'Idle';
    const act = actions[targetAnim] || actions['Idle'];
    if (act) {
      if (isCelebrating) {
        act.setEffectiveTimeScale(0.75);
      } else {
        act.setEffectiveTimeScale(0.85);
      }
      act.reset().fadeIn(0.2).play();
    }
    return () => {
      if (act) act.fadeOut(0.2);
    };
  }, [isCelebrating, actions]);

  useFrame((state, delta) => {
    if (isCelebrating && group.current) {
      group.current.rotation.y += delta * 1.5;
    }
    if (isThalaivarMode && auraRingRef.current) {
      auraRingRef.current.rotation.z += delta * 1.2;
    }
  });

  return (
    <group ref={group} position={position}>
      <primitive object={clonedScene} scale={[0.22, 0.22, 0.22]} />

      {/* Secret Golden Aura Effect when code=Thalaivar parameter is present */}
      {isThalaivarMode && (
        <group>
          {/* Pulsing Golden Energy Disc at feet */}
          <mesh ref={auraRingRef} position={[0, 0.02, 0]} rotation={[-Math.PI / 2, 0, 0]}>
            <ringGeometry args={[0.25, 0.65, 32]} />
            <meshStandardMaterial
              color="#fbbf24"
              emissive="#f59e0b"
              emissiveIntensity={isCelebrating ? 3.0 : 1.8}
              transparent
              opacity={0.85}
              side={THREE.DoubleSide}
            />
          </mesh>

          {/* Warm Golden Core Spotlight */}
          <pointLight
            position={[0, 0.8, 0]}
            color="#fbbf24"
            intensity={isCelebrating ? 4.0 : 2.2}
            distance={3.5}
          />
        </group>
      )}
    </group>
  );
}

function FallbackPlacedBox({ position }: { position: [number, number, number] }) {
  return (
    <group position={position}>
      <mesh position={[0, 0.35, 0]}>
        <cylinderGeometry args={[0.16, 0.24, 0.6, 16]} />
        <meshStandardMaterial color="#0891b2" emissive="#06b6d4" emissiveIntensity={1.2} roughness={0.2} metalness={0.8} />
      </mesh>
      <mesh position={[0, 0.75, 0]}>
        <sphereGeometry args={[0.14, 16, 16]} />
        <meshStandardMaterial color="#67e8f9" emissive="#22d3ee" emissiveIntensity={1.8} />
      </mesh>
    </group>
  );
}

interface BeaconPylonProps {
  row: number;
  col: number;
  n: number;
  tileSize?: number;
  visible?: boolean;
  isCelebrating?: boolean;
}

export function BeaconPylon({
  row,
  col,
  n,
  tileSize = 1.8,
  visible = true,
  isCelebrating = false,
}: BeaconPylonProps) {
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

  if (!visible) return null;

  return (
    <Suspense fallback={<FallbackPlacedBox position={position} />}>
      <PlacedRobotModel
        position={position}
        isCelebrating={isCelebrating}
        isThalaivarMode={isThalaivarMode}
      />
    </Suspense>
  );
}

useGLTF.preload('/models/mech.gltf');
