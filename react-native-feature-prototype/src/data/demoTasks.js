import { Task } from '../models/Task';

function localDateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function timeFromMinutes(totalMinutes) {
  const minutes = Math.max(0, Math.min(23 * 60 + 59, totalMinutes));
  const hours = Math.floor(minutes / 60);
  return `${String(hours).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
}

export function createDemoTasks() {
  const now = new Date();
  const today = localDateKey(now);
  const nowMinutes = now.getHours() * 60 + now.getMinutes();

  return [
    new Task({
      id: 'demo-morning-plan',
      label: 'Morning plan',
      startTime: '08:00',
      endTime: '08:30',
      color: '#8B5CF6',
      date: today,
      repeat: { type: 'daily' },
    }),
    new Task({
      id: 'demo-focus-block',
      label: 'Focus block',
      startTime: '09:00',
      endTime: '11:30',
      color: '#3B82F6',
      date: today,
      repeat: { type: 'weekly' },
    }),
    new Task({
      id: 'demo-lunch-walk',
      label: 'Lunch & walk',
      startTime: '12:30',
      endTime: '13:30',
      color: '#10B981',
      date: today,
    }),
    new Task({
      id: 'demo-current-focus',
      label: 'Current focus',
      startTime: timeFromMinutes(nowMinutes - 25),
      endTime: timeFromMinutes(nowMinutes + 35),
      color: '#F97316',
      date: today,
    }),
    new Task({
      id: 'demo-evening-workout',
      label: 'Evening workout',
      startTime: '18:00',
      endTime: '19:00',
      color: '#EF4444',
      date: today,
      repeat: { type: 'weekly' },
    }),
    new Task({
      id: 'demo-all-day',
      label: 'Stay hydrated',
      startTime: null,
      endTime: null,
      color: '#06B6D4',
      date: today,
      repeat: { type: 'daily' },
    }),
  ];
}
