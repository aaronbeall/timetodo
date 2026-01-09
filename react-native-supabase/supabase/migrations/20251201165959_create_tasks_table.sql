/*
  # TimeTodo Database Schema

  ## Overview
  Creates the core database structure for the TimeTodo app, a timer-based task management system.

  ## New Tables
  
  ### `tasks`
  Stores all task information including timing, appearance, and recurrence settings.
  
  **Columns:**
  - `id` (uuid, primary key) - Unique task identifier
  - `name` (text) - Task name/title
  - `color` (text) - Hex color code for task visualization
  - `icon` (text, optional) - Icon identifier for the task
  - `start_time` (time) - Daily start time (HH:MM:SS format)
  - `end_time` (time) - Daily end time (HH:MM:SS format)
  - `start_date` (date) - Date when task becomes active
  - `end_date` (date, optional) - Date when task stops (null for ongoing)
  - `repeat_pattern` (text) - Recurrence pattern: 'none', 'daily', 'weekdays', 'weekends', 'custom'
  - `repeat_days` (jsonb, optional) - Array of day numbers [0-6] for custom patterns (0=Sunday)
  - `start_sound` (text, optional) - Sound identifier for task start
  - `end_sound` (text, optional) - Sound identifier for task end
  - `notifications_enabled` (boolean) - Whether to show notifications
  - `is_paused` (boolean) - Whether task is temporarily paused
  - `is_completed` (boolean) - Whether task is marked as completed for the day
  - `snoozed_until` (timestamptz, optional) - When to resume after snooze
  - `created_at` (timestamptz) - Record creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp
  - `user_id` (uuid) - Owner of the task (for future auth integration)

  ## Security
  
  1. Enable Row Level Security on tasks table
  2. Create policy allowing all operations for authenticated users on their own tasks
  3. Create policy allowing all operations for anonymous users (for now, until auth is added)

  ## Notes
  
  - Time fields store time of day, not full timestamps
  - Date fields determine the active period for the task
  - Repeat pattern and days determine which days the task appears
  - Snooze functionality uses timestamptz for precise timing
  - User ID prepared for future authentication integration
*/

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  color text NOT NULL DEFAULT '#3B82F6',
  icon text DEFAULT 'circle',
  start_time time NOT NULL,
  end_time time NOT NULL,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  repeat_pattern text NOT NULL DEFAULT 'none',
  repeat_days jsonb DEFAULT '[]'::jsonb,
  start_sound text,
  end_sound text,
  notifications_enabled boolean DEFAULT true,
  is_paused boolean DEFAULT false,
  is_completed boolean DEFAULT false,
  snoozed_until timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  user_id uuid,
  CONSTRAINT valid_times CHECK (start_time < end_time),
  CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT valid_repeat_pattern CHECK (repeat_pattern IN ('none', 'daily', 'weekdays', 'weekends', 'custom'))
);

-- Enable Row Level Security
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Policy for authenticated users (for future use)
CREATE POLICY "Users can manage own tasks"
  ON tasks
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy for anonymous access (temporary - allows app to work without auth)
CREATE POLICY "Anonymous users can manage all tasks"
  ON tasks
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Create index for efficient queries by date range
CREATE INDEX IF NOT EXISTS idx_tasks_dates ON tasks(start_date, end_date);

-- Create index for user lookups
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_tasks_updated_at 
  BEFORE UPDATE ON tasks 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();
