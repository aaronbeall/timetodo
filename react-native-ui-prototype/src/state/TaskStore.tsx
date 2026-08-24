import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Notifications from 'expo-notifications';
import { createDemoTasks } from '../data/demoTasks';
import type { Task } from '../types';

const STORAGE_KEY = 'timetodo.tasks.v1';
const DEMO_SEEDED_KEY = 'timetodo.demoSeeded.v1';

type TaskMap = Record<string, Task>;

interface TaskContextValue {
  tasks: TaskMap;
  upsertTask: (task: Task) => void;
  deleteTask: (id: string) => void;
  togglePause: (id: string) => void;
}

const TaskContext = createContext<TaskContextValue | undefined>(undefined);

async function requestNotificationPermission() {
  const { status } = await Notifications.getPermissionsAsync();
  if (status !== 'granted') {
    await Notifications.requestPermissionsAsync();
  }
}

export const TaskProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [tasks, setTasks] = useState<TaskMap>({});
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const [raw, demoSeeded] = await Promise.all([
          AsyncStorage.getItem(STORAGE_KEY),
          AsyncStorage.getItem(DEMO_SEEDED_KEY),
        ]);
        const parsed: TaskMap = raw ? JSON.parse(raw) : {};
        const shouldSeedDemo =
          Object.keys(parsed).length === 0 && demoSeeded !== 'true';

        if (shouldSeedDemo) {
          setTasks(createDemoTasks());
          await AsyncStorage.setItem(DEMO_SEEDED_KEY, 'true');
        } else {
          setTasks(parsed);
        }
      } catch (e) {
        console.warn('Failed to load tasks', e);
      } finally {
        setHydrated(true);
      }
    })();
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(tasks)).catch((e) => {
      console.warn('Failed to persist tasks', e);
    });
  }, [hydrated, tasks]);

  const upsertTask = useCallback((task: Task) => {
    setTasks((prev) => {
      const next = { ...prev, [task.id]: task };
      return next;
    });
  }, []);

  const deleteTask = useCallback((id: string) => {
    setTasks((prev) => {
      const next = { ...prev };
      delete next[id];
      return next;
    });
  }, []);

  const togglePause = useCallback((id: string) => {
    setTasks((prev) => {
      const existing = prev[id];
      if (!existing) return prev;
      return {
        ...prev,
        [id]: { ...existing, paused: !existing.paused },
      };
    });
  }, []);

  useEffect(() => {
    requestNotificationPermission().catch(() => {});
  }, []);

  return (
    <TaskContext.Provider value={{ tasks, upsertTask, deleteTask, togglePause }}>
      {children}
    </TaskContext.Provider>
  );
};

export function useTasks(): TaskContextValue {
  const ctx = useContext(TaskContext);
  if (!ctx) {
    throw new Error('useTasks must be used within TaskProvider');
  }
  return ctx;
}


