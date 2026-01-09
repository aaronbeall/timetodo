import { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Modal,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ChevronLeft, ChevronRight, Plus } from 'lucide-react-native';
import { supabase, Task } from '@/lib/supabase';
import TaskListItem from '@/components/TaskListItem';
import NewTaskModal from '@/components/NewTaskModal';

export default function TasksScreen() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [tasks, setTasks] = useState<Task[]>([]);
  const [filteredTasks, setFilteredTasks] = useState<Task[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingTask, setEditingTask] = useState<Task | undefined>(undefined);

  useEffect(() => {
    loadTasks();
  }, []);

  useEffect(() => {
    filterTasksForDate(selectedDate);
  }, [selectedDate, tasks]);

  const loadTasks = async () => {
    const { data, error } = await supabase
      .from('tasks')
      .select('*')
      .order('start_time');

    if (!error && data) {
      setTasks(data);
    }
  };

  const filterTasksForDate = (date: Date) => {
    const dateStr = date.toISOString().split('T')[0];
    const dayOfWeek = date.getDay();

    const filtered = tasks.filter((task) => {
      if (task.is_paused) return false;

      const taskStart = task.start_date;
      const taskEnd = task.end_date || '9999-12-31';

      if (dateStr < taskStart || dateStr > taskEnd) return false;

      switch (task.repeat_pattern) {
        case 'none':
          return dateStr === taskStart;
        case 'daily':
          return true;
        case 'weekdays':
          return dayOfWeek >= 1 && dayOfWeek <= 5;
        case 'weekends':
          return dayOfWeek === 0 || dayOfWeek === 6;
        case 'custom':
          return task.repeat_days?.includes(dayOfWeek) ?? false;
        default:
          return false;
      }
    });

    setFilteredTasks(filtered);
  };

  const handlePreviousDay = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() - 1);
    setSelectedDate(newDate);
  };

  const handleNextDay = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() + 1);
    setSelectedDate(newDate);
  };

  const handleToday = () => {
    setSelectedDate(new Date());
  };

  const handleNewTask = () => {
    setEditingTask(undefined);
    setModalVisible(true);
  };

  const handleEditTask = (task: Task) => {
    setEditingTask(task);
    setModalVisible(true);
  };

  const handleDeleteTask = async (taskId: string) => {
    await supabase.from('tasks').delete().eq('id', taskId);
    loadTasks();
  };

  const handleTogglePause = async (taskId: string, isPaused: boolean) => {
    await supabase.from('tasks').update({ is_paused: !isPaused }).eq('id', taskId);
    loadTasks();
  };

  const handleSaveTask = async (taskData: Partial<Task>) => {
    if (editingTask?.id) {
      await supabase
        .from('tasks')
        .update(taskData)
        .eq('id', editingTask.id);
    } else {
      await supabase.from('tasks').insert([taskData]);
    }
    loadTasks();
    setModalVisible(false);
    setEditingTask(undefined);
  };

  const isToday = selectedDate.toDateString() === new Date().toDateString();

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Task Manager</Text>
      </View>

      <View style={styles.dateNavigation}>
        <TouchableOpacity
          style={styles.navButton}
          onPress={handlePreviousDay}>
          <ChevronLeft size={24} color="#64748B" />
        </TouchableOpacity>

        <View style={styles.dateInfo}>
          <Text style={styles.dateText}>
            {selectedDate.toLocaleDateString('en-US', {
              weekday: 'short',
              month: 'short',
              day: 'numeric',
            })}
          </Text>
          {!isToday && (
            <TouchableOpacity onPress={handleToday}>
              <Text style={styles.todayButton}>Today</Text>
            </TouchableOpacity>
          )}
        </View>

        <TouchableOpacity style={styles.navButton} onPress={handleNextDay}>
          <ChevronRight size={24} color="#64748B" />
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.taskList} showsVerticalScrollIndicator={false}>
        {filteredTasks.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateText}>No tasks for this day</Text>
            <Text style={styles.emptyStateSubtext}>
              Tap the + button to create a task
            </Text>
          </View>
        ) : (
          filteredTasks.map((task) => (
            <TaskListItem
              key={task.id}
              task={task}
              onEdit={handleEditTask}
              onDelete={handleDeleteTask}
              onTogglePause={handleTogglePause}
            />
          ))
        )}
      </ScrollView>

      <View style={styles.footer}>
        <TouchableOpacity style={styles.addButton} onPress={handleNewTask}>
          <Plus size={24} color="#FFFFFF" />
          <Text style={styles.addButtonText}>New Task</Text>
        </TouchableOpacity>
      </View>

      <Modal
        visible={modalVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => {
          setModalVisible(false);
          setEditingTask(undefined);
        }}>
        <NewTaskModal
          onClose={() => {
            setModalVisible(false);
            setEditingTask(undefined);
          }}
          onSave={handleSaveTask}
          initialTask={editingTask}
        />
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  header: {
    padding: 20,
    paddingBottom: 10,
  },
  headerTitle: {
    fontSize: 32,
    fontWeight: '700',
    color: '#1E293B',
  },
  dateNavigation: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    backgroundColor: '#F8FAFC',
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: '#E2E8F0',
  },
  navButton: {
    padding: 8,
  },
  dateInfo: {
    alignItems: 'center',
    gap: 4,
  },
  dateText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1E293B',
  },
  todayButton: {
    fontSize: 14,
    color: '#3B82F6',
    fontWeight: '500',
  },
  taskList: {
    flex: 1,
    padding: 20,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyStateText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#64748B',
    marginBottom: 8,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: '#94A3B8',
  },
  footer: {
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#E2E8F0',
  },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#3B82F6',
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 12,
    gap: 8,
  },
  addButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
