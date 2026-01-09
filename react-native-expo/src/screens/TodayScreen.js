import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import PolarClock from '../components/PolarClock';
import { loadTasks, getTasksForDate, updateTask, deleteTask } from '../utils/storage';
import { formatTime, isToday } from '../utils/dateUtils';
import { Task } from '../models/Task';

const TodayScreen = () => {
  const [tasks, setTasks] = useState([]);
  const [refreshing, setRefreshing] = useState(false);
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    loadTodayTasks();
    const interval = setInterval(() => {
      setCurrentTime(new Date());
    }, 60000); // Update every minute
    return () => clearInterval(interval);
  }, []);

  const loadTodayTasks = async () => {
    const today = new Date();
    const todayTasks = await getTasksForDate(today);
    setTasks(todayTasks);
  };

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadTodayTasks();
    setRefreshing(false);
  }, []);

  const handleSnooze = async (task) => {
    const snoozedTask = task.snooze();
    await updateTask(task.id, { snoozedUntil: snoozedTask.snoozedUntil });
    await loadTodayTasks();
  };

  const handleComplete = async (task) => {
    await updateTask(task.id, { completed: true });
    await loadTodayTasks();
  };

  const handleDelete = async (task) => {
    Alert.alert(
      'Delete Task',
      `Are you sure you want to delete "${task.label}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteTask(task.id);
            await loadTodayTasks();
          },
        },
      ]
    );
  };

  const activeTasks = tasks.filter(t => t.isActive(currentTime));
  const upcomingTasks = tasks.filter(t => t.isUpcoming(currentTime));
  const allDayTasks = tasks.filter(t => t.isAllDay() && !t.completed);

  const TaskItem = ({ task, isActive, isAllDay }) => {
    const isSnoozed = task.snoozedUntil && new Date(task.snoozedUntil) > currentTime;
    
    return (
      <View
        style={[
          styles.taskItem,
          isActive && styles.activeTaskItem,
          isAllDay && styles.allDayTaskItem,
        ]}
      >
        <View style={[styles.taskColorBar, { backgroundColor: task.color }]} />
        <View style={styles.taskContent}>
          <Text
            style={[
              styles.taskLabel,
              isActive && styles.activeTaskLabel,
              isAllDay && styles.allDayTaskLabel,
            ]}
          >
            {task.label}
          </Text>
          {!isAllDay && (
            <Text style={styles.taskTime}>
              {formatTime(task.startTime)} - {formatTime(task.endTime)}
            </Text>
          )}
          {isSnoozed && (
            <Text style={styles.snoozedText}>
              Snoozed until {formatTime(new Date(task.snoozedUntil).toTimeString().slice(0, 5))}
            </Text>
          )}
        </View>
        {isActive && !isAllDay && (
          <View style={styles.taskActions}>
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => handleSnooze(task)}
            >
              <Text style={styles.actionButtonText}>Snooze</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.actionButton, styles.completeButton]}
              onPress={() => handleComplete(task)}
            >
              <Text style={[styles.actionButtonText, styles.completeButtonText]}>
                ✓
              </Text>
            </TouchableOpacity>
          </View>
        )}
        {!isActive && !isAllDay && (
          <TouchableOpacity
            style={styles.deleteButton}
            onPress={() => handleDelete(task)}
          >
            <Text style={styles.deleteButtonText}>×</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView
        style={styles.scrollView}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        <View style={styles.header}>
          <Text style={styles.title}>Today</Text>
          <Text style={styles.subtitle}>
            {currentTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </Text>
        </View>

        <PolarClock tasks={tasks} />

        <View style={styles.tasksSection}>
          {activeTasks.length > 0 && (
            <>
              <Text style={styles.sectionTitle}>Active Now</Text>
              {activeTasks.map(task => (
                <TaskItem key={task.id} task={task} isActive={true} />
              ))}
            </>
          )}

          {upcomingTasks.length > 0 && (
            <>
              <Text style={[styles.sectionTitle, styles.upcomingSectionTitle]}>
                Upcoming
              </Text>
              {upcomingTasks.map(task => (
                <TaskItem key={task.id} task={task} isActive={false} />
              ))}
            </>
          )}

          {allDayTasks.length > 0 && (
            <>
              <Text style={[styles.sectionTitle, styles.allDaySectionTitle]}>
                All Day
              </Text>
              {allDayTasks.map(task => (
                <TaskItem key={task.id} task={task} isActive={false} isAllDay={true} />
              ))}
            </>
          )}

          {tasks.length === 0 && (
            <View style={styles.emptyState}>
              <Text style={styles.emptyStateText}>No tasks for today</Text>
              <Text style={styles.emptyStateSubtext}>
                Add tasks in the Tasks tab
              </Text>
            </View>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  scrollView: {
    flex: 1,
  },
  header: {
    padding: 20,
    paddingBottom: 10,
  },
  title: {
    fontSize: 34,
    fontWeight: '700',
    color: '#111827',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 16,
    color: '#6B7280',
  },
  tasksSection: {
    padding: 20,
    paddingTop: 10,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#111827',
    marginTop: 20,
    marginBottom: 12,
  },
  upcomingSectionTitle: {
    color: '#6B7280',
    fontSize: 16,
  },
  allDaySectionTitle: {
    color: '#6B7280',
    fontSize: 16,
  },
  taskItem: {
    flexDirection: 'row',
    backgroundColor: '#F9FAFB',
    borderRadius: 12,
    marginBottom: 8,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  activeTaskItem: {
    backgroundColor: '#EFF6FF',
    borderColor: '#3B82F6',
    borderWidth: 2,
    shadowColor: '#3B82F6',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  allDayTaskItem: {
    backgroundColor: '#FEF3C7',
    borderColor: '#F59E0B',
  },
  taskColorBar: {
    width: 4,
  },
  taskContent: {
    flex: 1,
    padding: 12,
  },
  taskLabel: {
    fontSize: 16,
    fontWeight: '500',
    color: '#111827',
    marginBottom: 4,
  },
  activeTaskLabel: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1E40AF',
  },
  allDayTaskLabel: {
    color: '#92400E',
  },
  taskTime: {
    fontSize: 14,
    color: '#6B7280',
  },
  snoozedText: {
    fontSize: 12,
    color: '#F59E0B',
    marginTop: 4,
    fontStyle: 'italic',
  },
  taskActions: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingRight: 12,
  },
  actionButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#3B82F6',
    borderRadius: 8,
    marginLeft: 8,
  },
  actionButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  completeButton: {
    backgroundColor: '#10B981',
    paddingHorizontal: 12,
  },
  completeButtonText: {
    fontSize: 18,
  },
  deleteButton: {
    padding: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteButtonText: {
    fontSize: 24,
    color: '#EF4444',
    fontWeight: '300',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyStateText: {
    fontSize: 18,
    color: '#6B7280',
    marginBottom: 8,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: '#9CA3AF',
  },
});

export default TodayScreen;

