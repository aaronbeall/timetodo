import { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Switch,
} from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';
import { X, ChevronDown, ChevronUp } from 'lucide-react-native';
import { Task } from '@/lib/supabase';
import RadialTimePicker from './RadialTimePicker';
import ColorPicker from './ColorPicker';

interface NewTaskModalProps {
  onClose: () => void;
  onSave: (task: Partial<Task>) => void;
  initialTask?: Task;
}

export default function NewTaskModal({
  onClose,
  onSave,
  initialTask,
}: NewTaskModalProps) {
  const [name, setName] = useState(initialTask?.name || '');
  const [color, setColor] = useState(initialTask?.color || '#3B82F6');
  const [startTime, setStartTime] = useState(
    initialTask?.start_time || '09:00:00'
  );
  const [endTime, setEndTime] = useState(initialTask?.end_time || '17:00:00');
  const [repeatPattern, setRepeatPattern] = useState<
    'none' | 'daily' | 'weekdays' | 'weekends' | 'custom'
  >(initialTask?.repeat_pattern || 'none');
  const [repeatDays, setRepeatDays] = useState<number[]>(
    initialTask?.repeat_days || []
  );
  const [notificationsEnabled, setNotificationsEnabled] = useState(
    initialTask?.notifications_enabled ?? true
  );
  const [startDate, setStartDate] = useState(
    initialTask?.start_date || new Date().toISOString().split('T')[0]
  );
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [isPickerDragging, setIsPickerDragging] = useState(false);

  const handleSave = () => {
    if (!name.trim()) return;

    const taskData: Partial<Task> = {
      name: name.trim(),
      color,
      start_time: startTime,
      end_time: endTime,
      start_date: startDate,
      repeat_pattern: repeatPattern,
      repeat_days: repeatPattern === 'custom' ? repeatDays : [],
      notifications_enabled: notificationsEnabled,
      is_paused: false,
      is_completed: false,
    };

    if (initialTask?.id) {
      taskData.id = initialTask.id;
    }

    onSave(taskData);
  };

  const handleTimeChange = (start: string, end: string) => {
    setStartTime(start);
    setEndTime(end);
  };

  const toggleRepeatDay = (day: number) => {
    setRepeatDays((prev) =>
      prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day]
    );
  };

  const repeatOptions: Array<{
    value: 'none' | 'daily' | 'weekdays' | 'weekends' | 'custom';
    label: string;
  }> = [
      { value: 'none', label: 'Once' },
      { value: 'daily', label: 'Daily' },
      { value: 'weekdays', label: 'Weekdays' },
      { value: 'weekends', label: 'Weekends' },
      { value: 'custom', label: 'Custom' },
    ];

  const weekDays = [
    { value: 0, label: 'Sun' },
    { value: 1, label: 'Mon' },
    { value: 2, label: 'Tue' },
    { value: 3, label: 'Wed' },
    { value: 4, label: 'Thu' },
    { value: 5, label: 'Fri' },
    { value: 6, label: 'Sat' },
  ];

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>
          {initialTask ? 'Edit Task' : 'New Task'}
        </Text>
        <TouchableOpacity onPress={onClose} style={styles.closeButton}>
          <X size={24} color="#64748B" />
        </TouchableOpacity>
      </View>

      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        scrollEnabled={!isPickerDragging}
        simultaneousHandlers={undefined}>
        <View style={styles.section}>
          <Text style={styles.label}>Task Name</Text>
          <TextInput
            style={styles.input}
            value={name}
            onChangeText={setName}
            placeholder="Enter task name"
            placeholderTextColor="#94A3B8"
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.label}>Time Frame</Text>
          <RadialTimePicker
            startTime={startTime}
            endTime={endTime}
            onChange={handleTimeChange}
            onDraggingChange={setIsPickerDragging}
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.label}>Color</Text>
          <ColorPicker selectedColor={color} onColorSelect={setColor} />
        </View>

        <TouchableOpacity
          style={styles.advancedToggle}
          onPress={() => setShowAdvanced(!showAdvanced)}>
          <Text style={styles.advancedToggleText}>Advanced Options</Text>
          {showAdvanced ? (
            <ChevronUp size={20} color="#64748B" />
          ) : (
            <ChevronDown size={20} color="#64748B" />
          )}
        </TouchableOpacity>

        {showAdvanced && (
          <>
            <View style={styles.section}>
              <Text style={styles.label}>Repeat</Text>
              <View style={styles.repeatOptions}>
                {repeatOptions.map((option) => (
                  <TouchableOpacity
                    key={option.value}
                    style={[
                      styles.repeatOption,
                      repeatPattern === option.value &&
                      styles.repeatOptionActive,
                    ]}
                    onPress={() => setRepeatPattern(option.value)}>
                    <Text
                      style={[
                        styles.repeatOptionText,
                        repeatPattern === option.value &&
                        styles.repeatOptionTextActive,
                      ]}>
                      {option.label}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>

              {repeatPattern === 'custom' && (
                <View style={styles.weekDays}>
                  {weekDays.map((day) => (
                    <TouchableOpacity
                      key={day.value}
                      style={[
                        styles.weekDay,
                        repeatDays.includes(day.value) && styles.weekDayActive,
                      ]}
                      onPress={() => toggleRepeatDay(day.value)}>
                      <Text
                        style={[
                          styles.weekDayText,
                          repeatDays.includes(day.value) &&
                          styles.weekDayTextActive,
                        ]}>
                        {day.label}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}
            </View>

            <View style={styles.section}>
              <View style={styles.switchRow}>
                <Text style={styles.label}>Notifications</Text>
                <Switch
                  value={notificationsEnabled}
                  onValueChange={setNotificationsEnabled}
                  trackColor={{ false: '#E2E8F0', true: '#93C5FD' }}
                  thumbColor={notificationsEnabled ? '#3B82F6' : '#F1F5F9'}
                />
              </View>
            </View>
          </>
        )}
      </ScrollView>

      <View style={styles.footer}>
        <TouchableOpacity style={styles.cancelButton} onPress={onClose}>
          <Text style={styles.cancelButtonText}>Cancel</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.saveButton, !name.trim() && styles.saveButtonDisabled]}
          onPress={handleSave}
          disabled={!name.trim()}>
          <Text style={styles.saveButtonText}>Save Task</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1E293B',
  },
  closeButton: {
    padding: 4,
  },
  content: {
    flex: 1,
    padding: 20,
  },
  section: {
    marginBottom: 24,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1E293B',
    marginBottom: 12,
  },
  input: {
    backgroundColor: '#F8FAFC',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: '#1E293B',
  },
  advancedToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    marginBottom: 16,
  },
  advancedToggleText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#64748B',
  },
  repeatOptions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  repeatOption: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 20,
    backgroundColor: '#F8FAFC',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  repeatOptionActive: {
    backgroundColor: '#3B82F6',
    borderColor: '#3B82F6',
  },
  repeatOptionText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#64748B',
  },
  repeatOptionTextActive: {
    color: '#FFFFFF',
  },
  weekDays: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 12,
  },
  weekDay: {
    flex: 1,
    paddingVertical: 12,
    alignItems: 'center',
    borderRadius: 8,
    backgroundColor: '#F8FAFC',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  weekDayActive: {
    backgroundColor: '#3B82F6',
    borderColor: '#3B82F6',
  },
  weekDayText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#64748B',
  },
  weekDayTextActive: {
    color: '#FFFFFF',
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  footer: {
    flexDirection: 'row',
    padding: 20,
    gap: 12,
    borderTopWidth: 1,
    borderTopColor: '#E2E8F0',
  },
  cancelButton: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
    borderRadius: 12,
    backgroundColor: '#F8FAFC',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  cancelButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#64748B',
  },
  saveButton: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
    borderRadius: 12,
    backgroundColor: '#3B82F6',
  },
  saveButtonDisabled: {
    backgroundColor: '#CBD5E1',
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});
