import { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import {
  Clock,
  Edit,
  Trash2,
  Pause,
  Play,
  ChevronDown,
  ChevronUp,
} from 'lucide-react-native';
import { Task } from '@/lib/supabase';

interface TaskListItemProps {
  task: Task;
  onEdit: (task: Task) => void;
  onDelete: (taskId: string) => void;
  onTogglePause: (taskId: string, isPaused: boolean) => void;
}

export default function TaskListItem({
  task,
  onEdit,
  onDelete,
  onTogglePause,
}: TaskListItemProps) {
  const [expanded, setExpanded] = useState(false);

  const getRepeatText = () => {
    switch (task.repeat_pattern) {
      case 'none':
        return 'Once';
      case 'daily':
        return 'Daily';
      case 'weekdays':
        return 'Weekdays';
      case 'weekends':
        return 'Weekends';
      case 'custom':
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return task.repeat_days?.map((d) => days[d]).join(', ') || 'Custom';
      default:
        return 'Unknown';
    }
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={styles.header}
        onPress={() => setExpanded(!expanded)}
        activeOpacity={0.7}>
        <View style={styles.headerLeft}>
          <View
            style={[styles.colorIndicator, { backgroundColor: task.color }]}
          />
          <View style={styles.headerInfo}>
            <Text style={styles.taskName}>{task.name}</Text>
            <View style={styles.timeRow}>
              <Clock size={14} color="#64748B" />
              <Text style={styles.timeText}>
                {formatTime(task.start_time)} - {formatTime(task.end_time)}
              </Text>
            </View>
          </View>
        </View>
        {expanded ? (
          <ChevronUp size={20} color="#64748B" />
        ) : (
          <ChevronDown size={20} color="#64748B" />
        )}
      </TouchableOpacity>

      {expanded && (
        <View style={styles.details}>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Repeat:</Text>
            <Text style={styles.detailValue}>{getRepeatText()}</Text>
          </View>

          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Start Date:</Text>
            <Text style={styles.detailValue}>
              {new Date(task.start_date).toLocaleDateString()}
            </Text>
          </View>

          {task.end_date && (
            <View style={styles.detailRow}>
              <Text style={styles.detailLabel}>End Date:</Text>
              <Text style={styles.detailValue}>
                {new Date(task.end_date).toLocaleDateString()}
              </Text>
            </View>
          )}

          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Notifications:</Text>
            <Text style={styles.detailValue}>
              {task.notifications_enabled ? 'Enabled' : 'Disabled'}
            </Text>
          </View>

          <View style={styles.actions}>
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => onEdit(task)}>
              <Edit size={18} color="#3B82F6" />
              <Text style={[styles.actionText, { color: '#3B82F6' }]}>
                Edit
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => onTogglePause(task.id, task.is_paused)}>
              {task.is_paused ? (
                <>
                  <Play size={18} color="#10B981" />
                  <Text style={[styles.actionText, { color: '#10B981' }]}>
                    Resume
                  </Text>
                </>
              ) : (
                <>
                  <Pause size={18} color="#F59E0B" />
                  <Text style={[styles.actionText, { color: '#F59E0B' }]}>
                    Pause
                  </Text>
                </>
              )}
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => onDelete(task.id)}>
              <Trash2 size={18} color="#EF4444" />
              <Text style={[styles.actionText, { color: '#EF4444' }]}>
                Delete
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
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
    backgroundColor: '#F8FAFC',
    borderRadius: 12,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
  },
  headerLeft: {
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
  headerInfo: {
    flex: 1,
  },
  taskName: {
    fontSize: 16,
    fontWeight: '600',
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
  details: {
    paddingHorizontal: 16,
    paddingBottom: 16,
    borderTopWidth: 1,
    borderTopColor: '#E2E8F0',
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  detailLabel: {
    fontSize: 14,
    color: '#64748B',
    fontWeight: '500',
  },
  detailValue: {
    fontSize: 14,
    color: '#1E293B',
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 12,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 6,
  },
  actionText: {
    fontSize: 14,
    fontWeight: '600',
  },
});
