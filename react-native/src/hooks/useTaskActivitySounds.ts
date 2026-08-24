import { useEffect, useRef } from 'react';
import { AppState } from 'react-native';
import { Audio } from 'expo-av';
import type { Task } from '../types';

async function playSoftChime() {
  try {
    const { sound } = await Audio.Sound.createAsync(
      require('../../assets/sounds/chime-soft.mp3')
    );
    await sound.playAsync();
    sound.unloadAsync();
  } catch {
    // swallow
  }
}

export function useTaskActivitySounds(tasks: Task[], nowMinutes: number) {
  const prevActiveIds = useRef<Set<string>>(new Set());
  const lastNow = useRef<number | null>(null);

  useEffect(() => {
    const active = new Set(
      tasks
        .filter(
          (t) =>
            nowMinutes >= t.startMinutes &&
            nowMinutes <= t.endMinutes &&
            !t.paused
        )
        .map((t) => t.id)
    );

    const prev = prevActiveIds.current;

    for (const id of active) {
      if (!prev.has(id)) {
        playSoftChime(); // start
      }
    }
    for (const id of prev) {
      if (!active.has(id)) {
        playSoftChime(); // end
      }
    }

    prevActiveIds.current = active;
    lastNow.current = nowMinutes;
  }, [nowMinutes, tasks]);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active' && lastNow.current != null) {
        // On resume, ensure we chime for any tasks that became active while away.
        // Simplified heuristic: just recompute using current time, the other effect will handle it.
      }
    });
    return () => sub.remove();
  }, []);
}



