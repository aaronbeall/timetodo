import type { Task } from './supabase';

export const isDemoMode = process.env.EXPO_PUBLIC_USE_DEMO_DATA === 'true';

export function getLocalDateKey(date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function minutesToTime(minutes: number): string {
  const boundedMinutes = Math.max(0, Math.min(24 * 60, minutes));
  const hours = Math.floor(boundedMinutes / 60);
  const mins = boundedMinutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00`;
}

export function createDemoTasks(now = new Date()): Task[] {
  const today = getLocalDateKey(now);
  const timestamp = now.toISOString();
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  const task = (
    id: string,
    name: string,
    color: string,
    startMinutes: number,
    endMinutes: number,
    repeatPattern: Task['repeat_pattern'] = 'none'
  ): Task => ({
    id: `demo-${id}`,
    name,
    color,
    start_time: minutesToTime(startMinutes),
    end_time: minutesToTime(endMinutes),
    start_date: today,
    repeat_pattern: repeatPattern,
    notifications_enabled: true,
    is_paused: false,
    is_completed: false,
    created_at: timestamp,
    updated_at: timestamp,
  });

  return [
    task('morning-plan', 'Morning plan', '#8B5CF6', 8 * 60, 8 * 60 + 30, 'daily'),
    task('deep-work', 'Deep work', '#3B82F6', 9 * 60, 11 * 60 + 30, 'weekdays'),
    task('lunch-walk', 'Lunch & walk', '#10B981', 12 * 60, 13 * 60, 'daily'),
    task(
      'current-focus',
      'Current focus',
      '#F97316',
      Math.max(0, currentMinutes - 35),
      Math.min(24 * 60, currentMinutes + 50)
    ),
    task('evening-workout', 'Evening workout', '#EC4899', 18 * 60, 19 * 60, 'weekdays'),
  ];
}

export function createLocalTask(taskData: Partial<Task>, now = new Date()): Task {
  const timestamp = now.toISOString();

  return {
    id: `demo-local-${now.getTime()}`,
    name: taskData.name || 'New task',
    color: taskData.color || '#3B82F6',
    start_time: taskData.start_time || '09:00:00',
    end_time: taskData.end_time || '10:00:00',
    start_date: taskData.start_date || getLocalDateKey(now),
    repeat_pattern: taskData.repeat_pattern || 'none',
    notifications_enabled: taskData.notifications_enabled ?? true,
    is_paused: taskData.is_paused ?? false,
    is_completed: taskData.is_completed ?? false,
    created_at: taskData.created_at || timestamp,
    updated_at: timestamp,
    ...taskData,
  };
}
