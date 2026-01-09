import { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Modal,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Plus } from 'lucide-react-native';
import { supabase, Task } from '@/lib/supabase';
import RadialClock from '@/components/RadialClock';
import TaskArcs from '@/components/TaskArcs';
import ActiveTasksList from '@/components/ActiveTasksList';
import NewTaskModal from '@/components/NewTaskModal';

export default function TimerScreen() {
  const [currentTime, setCurrentTime] = useState(new Date());
  const [tasks, setTasks] = useState<Task[]>([]);
  const [activeTasks, setActiveTasks] = useState<Task[]>([]);
  const [modalVisible, setModalVisible] = useState(false);

  useEffect(() => {
    loadTasks();

    const interval = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const active = tasks.filter((task) => {
      if (task.is_paused || task.is_completed) return false;

      const currentMinutes =
        currentTime.getHours() * 60 + currentTime.getMinutes();
      const [startHours, startMinutes] = task.start_time
        .split(':')
        .map(Number);
      const [endHours, endMinutes] = task.end_time.split(':').map(Number);
      const taskStart = startHours * 60 + startMinutes;
      const taskEnd = endHours * 60 + endMinutes;

      return currentMinutes >= taskStart && currentMinutes < taskEnd;
    });
    setActiveTasks(active);
  }, [currentTime, tasks]);

  const loadTasks = async () => {
    const { data, error } = await supabase
      .from('tasks')
      .select('*')
      .order('start_time');

    if (!error && data) {
      setTasks(data);
    }
  };

  const handleSnooze = async (taskId: string) => {
    const snoozeUntil = new Date(currentTime.getTime() + 15 * 60 * 1000);
    await supabase
      .from('tasks')
      .update({ snoozed_until: snoozeUntil.toISOString() })
      .eq('id', taskId);
    loadTasks();
  };

  const handleComplete = async (taskId: string) => {
    await supabase
      .from('tasks')
      .update({ is_completed: true })
      .eq('id', taskId);
    loadTasks();
  };

  const handleCreateTask = async (taskData: Partial<Task>) => {
    await supabase.from('tasks').insert([taskData]);
    loadTasks();
    setModalVisible(false);
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>TimeTodo</Text>
          <Text style={styles.headerSubtitle}>
            {currentTime.toLocaleDateString('en-US', {
              weekday: 'long',
              month: 'long',
              day: 'numeric',
            })}
          </Text>
        </View>

        <View style={styles.clockContainer}>
          <View style={styles.clockWrapper}>
            <TaskArcs tasks={tasks} currentTime={currentTime} />
            <RadialClock currentTime={currentTime} />
          </View>
        </View>

        <ActiveTasksList
          tasks={activeTasks}
          onSnooze={handleSnooze}
          onComplete={handleComplete}
        />

        <View style={styles.footer}>
          <TouchableOpacity
            style={styles.addButton}
            onPress={() => setModalVisible(true)}>
            <Plus size={24} color="#FFFFFF" />
            <Text style={styles.addButtonText}>New Task</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>

      <Modal
        visible={modalVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setModalVisible(false)}>
        <NewTaskModal
          onClose={() => setModalVisible(false)}
          onSave={handleCreateTask}
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
  scrollContent: {
    flexGrow: 1,
  },
  header: {
    padding: 20,
    paddingBottom: 10,
  },
  headerTitle: {
    fontSize: 32,
    fontWeight: '700',
    color: '#1E293B',
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 16,
    color: '#64748B',
  },
  clockContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 40,
  },
  clockWrapper: {
    width: 320,
    height: 320,
    alignItems: 'center',
    justifyContent: 'center',
  },
  footer: {
    padding: 20,
    marginTop: 'auto',
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
