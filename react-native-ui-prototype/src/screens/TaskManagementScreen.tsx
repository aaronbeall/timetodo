import React, { useMemo, useState } from 'react';
import {
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  FlatList,
  TouchableOpacity,
  TextInput,
} from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';
import { useNavigation } from '@react-navigation/native';
import { colors, spacing, typography, radius } from '../theme';
import { useTasks } from '../state/TaskStore';
import type { Task, RepeatRule } from '../types';

interface EditableTask extends Task {
  isNew?: boolean;
}

const REPEAT_OPTIONS: { label: string; value: RepeatRule }[] = [
  { label: 'None', value: 'none' },
  { label: 'Daily', value: 'daily' },
  { label: 'Weekdays', value: 'weekdays' },
  { label: 'Weekends', value: 'weekends' },
];

export const TaskManagementScreen: React.FC = () => {
  const navigation = useNavigation();
  const { tasks, upsertTask, deleteTask, togglePause } = useTasks();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const tasksForDay: EditableTask[] = useMemo(
    () =>
      Object.values(tasks).sort(
        (a, b) => a.startMinutes - b.startMinutes
      ),
    [tasks]
  );

  const handleSave = (task: EditableTask) => {
    upsertTask({
      ...task,
      repeat: task.repeat ?? 'none',
    });
  };

  const handleAddNew = () => {
    const id = `task-${Date.now()}`;
    const baseStart = 9 * 60;
    const baseEnd = 10 * 60;
    const newTask: EditableTask = {
      id,
      name: 'New task',
      color: '#7B6CFF',
      startMinutes: baseStart,
      endMinutes: baseEnd,
      repeat: 'none',
      isNew: true,
    };
    upsertTask(newTask);
    setExpandedId(id);
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.root}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.navText}>‹ Today</Text>
          </TouchableOpacity>
          <Text style={styles.title}>Plan your day</Text>
          <View style={{ width: 60 }} />
        </View>

        <View style={styles.dateRow}>
          <TouchableOpacity
            style={styles.datePill}
            onPress={() =>
              setSelectedDate(
                new Date(selectedDate.getTime() - 24 * 60 * 60 * 1000)
              )
            }
          >
            <Text style={styles.datePillText}>Prev</Text>
          </TouchableOpacity>
          <Text style={styles.dateLabel}>
            {selectedDate.toLocaleDateString(undefined, {
              weekday: 'short',
              month: 'short',
              day: 'numeric',
            })}
          </Text>
          <TouchableOpacity
            style={styles.datePill}
            onPress={() =>
              setSelectedDate(
                new Date(selectedDate.getTime() + 24 * 60 * 60 * 1000)
              )
            }
          >
            <Text style={styles.datePillText}>Next</Text>
          </TouchableOpacity>
        </View>

        <FlatList
          data={tasksForDay}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingBottom: spacing.xl }}
          renderItem={({ item }) => (
            <TaskRow
              task={item}
              expanded={expandedId === item.id}
              onToggleExpand={() =>
                setExpandedId((curr) => (curr === item.id ? null : item.id))
              }
              onSave={handleSave}
              onDelete={() => deleteTask(item.id)}
              onTogglePause={() => togglePause(item.id)}
            />
          )}
        />

        <View style={styles.footer}>
          <TouchableOpacity style={styles.addTaskButton} onPress={handleAddNew}>
            <Text style={styles.addTaskLabel}>Add task</Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

interface TaskRowProps {
  task: EditableTask;
  expanded: boolean;
  onToggleExpand: () => void;
  onSave: (task: EditableTask) => void;
  onDelete: () => void;
  onTogglePause: () => void;
}

const TaskRow: React.FC<TaskRowProps> = ({
  task,
  expanded,
  onToggleExpand,
  onSave,
  onDelete,
  onTogglePause,
}) => {
  const [draft, setDraft] = useState<EditableTask>(task);

  const applyTimeChange = (field: 'startMinutes' | 'endMinutes', date: Date) => {
    const minutes = date.getHours() * 60 + date.getMinutes();
    setDraft((d) => ({ ...d, [field]: minutes }));
  };

  const commit = () => {
    onSave(draft);
  };

  return (
    <View style={styles.taskCard}>
      <TouchableOpacity style={styles.taskHeader} onPress={onToggleExpand}>
        <View style={[styles.colorDot, { backgroundColor: task.color }]} />
        <View style={{ flex: 1 }}>
          <Text style={styles.taskName}>{task.name}</Text>
          <Text style={styles.taskTime}>
            {formatMinutes(task.startMinutes)} — {formatMinutes(task.endMinutes)}
          </Text>
        </View>
        <Text style={styles.chevron}>{expanded ? '▴' : '▾'}</Text>
      </TouchableOpacity>

      {expanded && (
        <View style={styles.editor}>
          <Text style={styles.label}>Name</Text>
          <TextInput
            style={styles.input}
            value={draft.name}
            onChangeText={(text) => setDraft((d) => ({ ...d, name: text }))}
            onBlur={commit}
            placeholder="Task name"
            placeholderTextColor={colors.textMuted}
          />

          <View style={styles.row}>
            <View style={styles.column}>
              <Text style={styles.label}>Start</Text>
              <DateTimePicker
                mode="time"
                value={minutesToDate(draft.startMinutes)}
                onChange={(_, date) => date && applyTimeChange('startMinutes', date)}
              />
            </View>
            <View style={styles.column}>
              <Text style={styles.label}>End</Text>
              <DateTimePicker
                mode="time"
                value={minutesToDate(draft.endMinutes)}
                onChange={(_, date) => date && applyTimeChange('endMinutes', date)}
              />
            </View>
          </View>

          <Text style={styles.label}>Repeat</Text>
          <View style={styles.chipRow}>
            {REPEAT_OPTIONS.map((opt) => (
              <TouchableOpacity
                key={opt.value}
                style={[
                  styles.chip,
                  draft.repeat === opt.value && styles.chipSelected,
                ]}
                onPress={() =>
                  setDraft((d) => ({ ...d, repeat: opt.value as RepeatRule }))
                }
              >
                <Text
                  style={[
                    styles.chipLabel,
                    draft.repeat === opt.value && styles.chipLabelSelected,
                  ]}
                >
                  {opt.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <View style={styles.row}>
            <TouchableOpacity style={styles.outlineButton} onPress={onTogglePause}>
              <Text style={styles.outlineButtonLabel}>
                {task.paused ? 'Resume' : 'Pause'}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.dangerButton} onPress={onDelete}>
              <Text style={styles.dangerButtonLabel}>Delete</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
    </View>
  );
};

function formatMinutes(m: number) {
  const h = Math.floor(m / 60);
  const mm = Math.floor(m % 60)
    .toString()
    .padStart(2, '0');
  return `${h}:${mm}`;
}

function minutesToDate(minutes: number): Date {
  const d = new Date();
  d.setHours(Math.floor(minutes / 60));
  d.setMinutes(minutes % 60);
  d.setSeconds(0);
  d.setMilliseconds(0);
  return d;
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  root: {
    flex: 1,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.lg,
  },
  navText: {
    ...typography.body,
    color: colors.textSecondary,
  },
  title: {
    ...typography.subtitle,
    color: colors.textPrimary,
  },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.lg,
  },
  datePill: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    backgroundColor: colors.surfaceSoft,
  },
  datePillText: {
    fontSize: 13,
    color: colors.textSecondary,
  },
  dateLabel: {
    ...typography.body,
    color: colors.textPrimary,
  },
  taskCard: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  taskHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  colorDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: spacing.md,
  },
  taskName: {
    ...typography.body,
    color: colors.textPrimary,
  },
  taskTime: {
    fontSize: 13,
    color: colors.textMuted,
  },
  chevron: {
    color: colors.textMuted,
    marginLeft: spacing.sm,
  },
  editor: {
    marginTop: spacing.sm,
    gap: spacing.sm,
  },
  label: {
    ...typography.label,
    color: colors.textMuted,
    marginBottom: 4,
  },
  input: {
    borderRadius: radius.md,
    backgroundColor: colors.surfaceSoft,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    color: colors.textPrimary,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: spacing.md,
  },
  column: {
    flex: 1,
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  chip: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    backgroundColor: colors.surfaceSoft,
  },
  chipSelected: {
    backgroundColor: colors.accentSoft,
  },
  chipLabel: {
    fontSize: 13,
    color: colors.textSecondary,
  },
  chipLabelSelected: {
    color: colors.accentMuted,
  },
  outlineButton: {
    flex: 1,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.divider,
    alignItems: 'center',
  },
  outlineButtonLabel: {
    fontSize: 13,
    color: colors.textSecondary,
  },
  dangerButton: {
    flex: 1,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    backgroundColor: '#2A1120',
    alignItems: 'center',
  },
  dangerButtonLabel: {
    fontSize: 13,
    color: colors.danger,
  },
  footer: {
    paddingVertical: spacing.md,
  },
  addTaskButton: {
    backgroundColor: colors.accentSoft,
    borderRadius: radius.pill,
    paddingVertical: spacing.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addTaskLabel: {
    ...typography.body,
    color: colors.accentMuted,
    fontWeight: '500',
  },
});


