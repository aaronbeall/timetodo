import { format, addDays, subDays, isSameDay, startOfDay } from 'date-fns';

export const formatTime = (timeString) => {
  if (!timeString) return '';
  const [hours, minutes] = timeString.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes.toString().padStart(2, '0')} ${period}`;
};

export const formatDate = (date) => {
  if (typeof date === 'string') {
    date = new Date(date);
  }
  return format(date, 'EEEE, MMMM d, yyyy');
};

export const formatDateShort = (date) => {
  if (typeof date === 'string') {
    date = new Date(date);
  }
  return format(date, 'MMM d, yyyy');
};

export const getNextDay = (date) => {
  return addDays(new Date(date), 1);
};

export const getPrevDay = (date) => {
  return subDays(new Date(date), 1);
};

export const isToday = (date) => {
  return isSameDay(new Date(date), new Date());
};

export const getCurrentTimeAngle = () => {
  const now = new Date();
  const hours = now.getHours();
  const minutes = now.getMinutes();
  const totalMinutes = hours * 60 + minutes;
  return (totalMinutes / (24 * 60)) * 360 - 90; // -90 to start at top
};

