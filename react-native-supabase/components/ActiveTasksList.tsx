import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Task } from '@/lib/supabase';
import { Clock, CheckCircle, BellOff } from 'lucide-react-native';

interface ActiveTasksListProps {
  tasks: Task[];
  onSnooze: (taskId: string) => void;
  onComplete: (taskId: string) => void;
}

export default function ActiveTasksList({
  tasks,
  onSnooze,
  onComplete,
}: ActiveTasksListProps) {
  if (tasks.length === 0) {
    return null;
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Active Tasks</Text>
      {tasks.map((task) => (
        <View key={task.id} style={styles.taskCard}>
          <View style={styles.taskInfo}>
            <View
              style={[styles.colorIndicator, { backgroundColor: task.color }]}
            />
            <View style={styles.taskDetails}>
              <Text style={styles.taskName}>{task.name}</Text>
              <View style={styles.timeRow}>
                <Clock size={14} color="#64748B" />
                <Text style={styles.timeText}>
                  {formatTime(task.start_time)} - {formatTime(task.end_time)}
                </Text>
              </View>
            </View>
          </View>
          <View style={styles.actions}>
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => onSnooze(task.id)}>
              <BellOff size={20} color="#64748B" />
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => onComplete(task.id)}>
              <CheckCircle size={20} color="#10B981" />
            </TouchableOpacity>
          </View>
        </View>
      ))}
    </View>
  );
}

function formatTime(timeStr: string): string {
  const [hours, minutes] = timeStr.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes.toString().padStart(2, '0')} ${period}`;
}

const styles = StyleSheet.create({
  container: {
    padding: 20,
    backgroundColor: '#FFFFFF',
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1E293B',
    marginBottom: 12,
  },
  taskCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#F8FAFC',
    padding: 16,
    borderRadius: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  taskInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  colorIndicator: {
    width: 4,
    height: 40,
    borderRadius: 2,
    marginRight: 12,
  },
  taskDetails: {
    flex: 1,
  },
  taskName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#1E293B',
    marginBottom: 4,
  },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  timeText: {
    fontSize: 14,
    color: '#64748B',
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
  },
  actionButton: {
    padding: 8,
    borderRadius: 8,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
});
