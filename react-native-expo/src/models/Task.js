export class Task {
  constructor({
    id = Date.now().toString(),
    label = '',
    startTime = null, // HH:mm format or null for all-day
    endTime = null, // HH:mm format or null for all-day
    color = '#3B82F6',
    date = new Date().toISOString().split('T')[0], // YYYY-MM-DD
    repeat = null, // { type: 'daily'|'weekly'|'monthly'|'custom', days: [0-6], interval: number }
    completed = false,
    snoozedUntil = null, // ISO string
    createdAt = new Date().toISOString(),
  } = {}) {
    this.id = id;
    this.label = label;
    this.startTime = startTime;
    this.endTime = endTime;
    this.color = color;
    this.date = date;
    this.repeat = repeat;
    this.completed = completed;
    this.snoozedUntil = snoozedUntil;
    this.createdAt = createdAt;
  }

  isAllDay() {
    return this.startTime === null && this.endTime === null;
  }

  getStartAngle() {
    if (this.isAllDay()) return 0;
    const [hours, minutes] = this.startTime.split(':').map(Number);
    const totalMinutes = hours * 60 + minutes;
    return (totalMinutes / (24 * 60)) * 360 - 90; // -90 to start at top
  }

  getEndAngle() {
    if (this.isAllDay()) return 360;
    const [hours, minutes] = this.endTime.split(':').map(Number);
    const totalMinutes = hours * 60 + minutes;
    return (totalMinutes / (24 * 60)) * 360 - 90;
  }

  isActive(currentTime) {
    if (this.completed || this.isAllDay()) return false;
    if (this.snoozedUntil && new Date(this.snoozedUntil) > currentTime) return false;
    
    const [currentHours, currentMinutes] = [
      currentTime.getHours(),
      currentTime.getMinutes()
    ];
    const currentTotalMinutes = currentHours * 60 + currentMinutes;
    
    const [startHours, startMinutes] = this.startTime.split(':').map(Number);
    const startTotalMinutes = startHours * 60 + startMinutes;
    
    const [endHours, endMinutes] = this.endTime.split(':').map(Number);
    const endTotalMinutes = endHours * 60 + endMinutes;
    
    return currentTotalMinutes >= startTotalMinutes && currentTotalMinutes < endTotalMinutes;
  }

  isUpcoming(currentTime) {
    if (this.completed || this.isAllDay()) return false;
    if (this.snoozedUntil && new Date(this.snoozedUntil) > currentTime) return false;
    
    const [currentHours, currentMinutes] = [
      currentTime.getHours(),
      currentTime.getMinutes()
    ];
    const currentTotalMinutes = currentHours * 60 + currentMinutes;
    
    const [startHours, startMinutes] = this.startTime.split(':').map(Number);
    const startTotalMinutes = startHours * 60 + startMinutes;
    
    return currentTotalMinutes < startTotalMinutes;
  }

  snooze() {
    const now = new Date();
    const snoozeTime = new Date(now.getTime() + 15 * 60 * 1000); // 15 minutes
    this.snoozedUntil = snoozeTime.toISOString();
    return this;
  }

  toJSON() {
    return {
      id: this.id,
      label: this.label,
      startTime: this.startTime,
      endTime: this.endTime,
      color: this.color,
      date: this.date,
      repeat: this.repeat,
      completed: this.completed,
      snoozedUntil: this.snoozedUntil,
      createdAt: this.createdAt,
    };
  }

  static fromJSON(json) {
    return new Task(json);
  }
}

