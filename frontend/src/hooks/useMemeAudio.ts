'use client';

import { useEffect, useRef } from 'react';
import type { SSEEvent } from './useNQueensStream';

export function useMemeAudio(
  currentEvent: SSEEvent | null,
  playbackStatus: 'IDLE' | 'PLAYING' | 'FINISHED',
  events: SSEEvent[]
) {
  const victoryAudioRef = useRef<HTMLAudioElement | null>(null);
  const failureAudioRef = useRef<HTMLAudioElement | null>(null);
  const isThalaivarModeRef = useRef<boolean>(false);
  const failTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Initialize audio elements and check URL for secret code=Thalaivar
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search);
      isThalaivarModeRef.current = params.get('code')?.toLowerCase() === 'thalaivar';

      // Load victory audio (vazhthukkal.mpeg / vazhthukkal.mp3)
      const vAudio = new Audio('/audio/vazhthukkal.mpeg');
      vAudio.onerror = () => {
        vAudio.src = '/audio/vazhthukkal.mp3';
      };
      victoryAudioRef.current = vAudio;

      // Load failure/janda audio (janda.mpeg / janda.mp3 / failure.mpeg / failure.mp3)
      const fAudio = new Audio('/audio/janda.mpeg');
      fAudio.onerror = () => {
        fAudio.src = '/audio/janda.mp3';
        fAudio.onerror = () => {
          fAudio.src = '/audio/failure.mpeg';
          fAudio.onerror = () => {
            fAudio.src = '/audio/failure.mp3';
          };
        };
      };

      // Trim janda audio strictly from 1.0s to 4.0s
      fAudio.ontimeupdate = () => {
        if (fAudio.currentTime >= 4.0) {
          fAudio.pause();
          fAudio.currentTime = 1.0;
        }
      };

      failureAudioRef.current = fAudio;
    }
  }, []);

  // Unlock browser audio restrictions on initial user interaction
  useEffect(() => {
    const unlockAudio = () => {
      if (victoryAudioRef.current) {
        victoryAudioRef.current.load();
      }
      if (failureAudioRef.current) {
        failureAudioRef.current.load();
      }
      window.removeEventListener('click', unlockAudio);
    };
    window.addEventListener('click', unlockAudio);
    return () => window.removeEventListener('click', unlockAudio);
  }, []);

  // Trigger audio clips on simulation events when Thalaivar Mode is active
  useEffect(() => {
    if (!isThalaivarModeRef.current || !currentEvent) return;

    // Victory sound on valid position (PLACE_BEACON) or solution celebration (SOLUTION_FOUND)
    if (currentEvent.type === 'PLACE_BEACON' || currentEvent.type === 'SOLUTION_FOUND') {
      if (victoryAudioRef.current) {
        victoryAudioRef.current.currentTime = 0;
        victoryAudioRef.current.play().catch(() => {});
      }
    } 
    // Janda fail sound (trimmed from 1.0s to 4.0s) when character dies / conflict occurs / search completes
    else if (currentEvent.type === 'CONFLICT' || currentEvent.type === 'REMOVE_BEACON' || currentEvent.type === 'COMPLETE') {
      if (failureAudioRef.current) {
        if (failTimeoutRef.current) clearTimeout(failTimeoutRef.current);

        failureAudioRef.current.currentTime = 1.0;
        failureAudioRef.current.play().catch(() => {});

        // Hard safety stop after 3 seconds (from 1.0s to 4.0s)
        failTimeoutRef.current = setTimeout(() => {
          if (failureAudioRef.current) {
            failureAudioRef.current.pause();
            failureAudioRef.current.currentTime = 1.0;
          }
        }, 3000);
      }
    }
  }, [currentEvent]);
}
