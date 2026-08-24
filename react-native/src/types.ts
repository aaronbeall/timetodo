export type RepeatRule =
  | 'none'
  | 'daily'
  | 'weekdays'
  | 'weekends';

export interface Task {
  id: string;
  name: string;
  startMinutes: number;
  endMinutes: number;
  color: string;
  active?: boolean;
  startDate?: string;
  endDate?: string | null;
  repeat?: RepeatRule;
  iconName?: string;
  startSoundUri?: string | null;
  endSoundUri?: string | null;
  notificationsEnabled?: boolean;
  paused?: boolean;
  _layerIndex?: number;
  _layerCount?: number;
}



