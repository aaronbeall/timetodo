import AsyncStorage from '@react-native-async-storage/async-storage';
import { Task } from '../models/Task';

const TASKS_KEY = '@timetodo:tasks';

export const loadTasks = async () => {
  try {
    const jsonValue = await AsyncStorage.getItem(TASKS_KEY);
    if (jsonValue != null) {
      const tasks = JSON.parse(jsonValue);
      return tasks.map(t => Task.fromJSON(t));
    }
    return [];
  } catch (e) {
    console.error('Error loading tasks:', e);
    return [];
  }
};

export const saveTasks = async (tasks) => {
  try {
    const jsonValue = JSON.stringify(tasks.map(t => t.toJSON()));
    await AsyncStorage.setItem(TASKS_KEY, jsonValue);
  } catch (e) {
    console.error('Error saving tasks:', e);
  }
};

export const addTask = async (task) => {
  const tasks = await loadTasks();
  tasks.push(task);
  await saveTasks(tasks);
  return task;
};

export const updateTask = async (taskId, updates) => {
  const tasks = await loadTasks();
  const index = tasks.findIndex(t => t.id === taskId);
  if (index !== -1) {
    const updatedTask = new Task({ ...tasks[index].toJSON(), ...updates });
    tasks[index] = updatedTask;
    await saveTasks(tasks);
    return updatedTask;
  }
  return null;
};

export const deleteTask = async (taskId) => {
  const tasks = await loadTasks();
  const filtered = tasks.filter(t => t.id !== taskId);
  await saveTasks(filtered);
};

export const getTasksForDate = async (date) => {
  const tasks = await loadTasks();
  const dateStr = typeof date === 'string' ? date : date.toISOString().split('T')[0];
  
  return tasks.filter(task => {
    // Direct date match
    if (task.date === dateStr) return true;
    
    // Check repeat rules
    if (task.repeat) {
      const taskDate = new Date(task.date);
      const checkDate = new Date(dateStr);
      
      if (task.repeat.type === 'daily') {
        return checkDate >= taskDate;
      }
      
      if (task.repeat.type === 'weekly') {
        const daysDiff = Math.floor((checkDate - taskDate) / (1000 * 60 * 60 * 24));
        if (daysDiff < 0) return false;
        if (task.repeat.interval) {
          return daysDiff % (task.repeat.interval * 7) === 0;
        }
        if (task.repeat.days && task.repeat.days.length > 0) {
          return task.repeat.days.includes(checkDate.getDay());
        }
        return daysDiff % 7 === 0;
      }
      
      if (task.repeat.type === 'monthly') {
        return checkDate.getDate() === taskDate.getDate() && checkDate >= taskDate;
      }
    }
    
    return false;
  });
};

