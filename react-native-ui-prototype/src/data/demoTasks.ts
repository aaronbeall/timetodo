import type { Task } from '../types';

function localDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function createDemoTasks(): Record<string, Task> {
  const today = localDateKey(new Date());
  const tasks: Task[] = [
    {
      id: 'demo-morning-plan',
      name: 'Morning plan',
      startMinutes: 8 * 60,
      endMinutes: 8 * 60 + 30,
      color: '#A699FF',
      startDate: today,
      repeat: 'weekdays',
    },
    {
      id: 'demo-focus-block',
      name: 'Focus block',
      startMinutes: 9 * 60,
      endMinutes: 11 * 60 + 30,
      color: '#5B8CFF',
      startDate: today,
      repeat: 'weekdays',
    },
    {
      id: 'demo-team-sync',
      name: 'Team sync',
      startMinutes: 10 * 60 + 30,
      endMinutes: 11 * 60 + 15,
      color: '#FF8A65',
      startDate: today,
      repeat: 'weekdays',
    },
    {
      id: 'demo-lunch-walk',
      name: 'Lunch & walk',
      startMinutes: 12 * 60 + 30,
      endMinutes: 13 * 60 + 30,
      color: '#4CAF7D',
      startDate: today,
      repeat: 'daily',
    },
    {
      id: 'demo-design-review',
      name: 'Design review',
      startMinutes: 14 * 60 + 15,
      endMinutes: 15 * 60 + 30,
      color: '#FFB74D',
      startDate: today,
      repeat: 'none',
    },
    {
      id: 'demo-evening-workout',
      name: 'Evening workout',
      startMinutes: 18 * 60,
      endMinutes: 19 * 60,
      color: '#FF5C7A',
      startDate: today,
      repeat: 'weekdays',
    },
  ];

  return Object.fromEntries(tasks.map((task) => [task.id, task]));
}
