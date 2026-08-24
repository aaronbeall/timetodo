import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Notifications from 'expo-notifications';
import type { Task } from '../types';

const STORAGE_KEY = 'timetodo.tasks.v1';

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

  useEffect(() => {
    (async () => {
      try {
        const raw = await AsyncStorage.getItem(STORAGE_KEY);
        if (raw) {
          const parsed: TaskMap = JSON.parse(raw);
          setTasks(parsed);
        }
      } catch (e) {
        console.warn('Failed to load tasks', e);
      }
    })();
  }, []);

  useEffect(() => {
    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(tasks)).catch((e) => {
      console.warn('Failed to persist tasks', e);
    });
  }, [tasks]);

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



