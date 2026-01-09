import { createClient } from '@supabase/supabase-js';
import 'react-native-url-polyfill/auto';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export interface Task {
  id: string;
  name: string;
  color: string;
  icon?: string;
  start_time: string;
  end_time: string;
  start_date: string;
  end_date?: string;
  repeat_pattern: 'none' | 'daily' | 'weekdays' | 'weekends' | 'custom';
  repeat_days?: number[];
  start_sound?: string;
  end_sound?: string;
  notifications_enabled: boolean;
  is_paused: boolean;
  is_completed: boolean;
  snoozed_until?: string;
  created_at: string;
  updated_at: string;
  user_id?: string;
}
