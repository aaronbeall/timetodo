import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
  Modal,
  RefreshControl,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { formatDate, formatDateShort, getNextDay, getPrevDay, formatTime } from '../utils/dateUtils';
import { getTasksForDate, addTask, updateTask, deleteTask } from '../utils/storage';
import { Task } from '../models/Task';

const COLORS = [
  '#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6',
  '#EC4899', '#06B6D4', '#84CC16', '#F97316', '#6366F1',
];

const TasksScreen = () => {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [tasks, setTasks] = useState([]);
  const [expandedTaskId, setExpandedTaskId] = useState(null);
  const [editingTask, setEditingTask] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadTasks();
  }, [selectedDate]);

  const loadTasks = async () => {
    const dateTasks = await getTasksForDate(selectedDate);
    setTasks(dateTasks.sort((a, b) => {
      if (a.isAllDay() && !b.isAllDay()) return 1;
      if (!a.isAllDay() && b.isAllDay()) return -1;
      if (!a.startTime || !b.startTime) return 0;
      return a.startTime.localeCompare(b.startTime);
    }));
  };

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadTasks();
    setRefreshing(false);
  }, [selectedDate]);

  const handlePrevDay = () => {
    setSelectedDate(getPrevDay(selectedDate));
    setExpandedTaskId(null);
  };

  const handleNextDay = () => {
    setSelectedDate(getNextDay(selectedDate));
    setExpandedTaskId(null);
  };

  const handleAddTask = () => {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    const defaultStartTime = `${hours}:${minutes}`;
    const nextHour = (now.getHours() + 1) % 24;
    const defaultEndTime = `${nextHour.toString().padStart(2, '0')}:${minutes}`;
    
    const newTask = new Task({
      label: 'New Task',
      startTime: defaultStartTime,
      endTime: defaultEndTime,
      date: selectedDate.toISOString().split('T')[0],
      color: COLORS[0],
    });
    
    setEditingTask(newTask);
    setExpandedTaskId(newTask.id);
  };

  const handleSaveTask = async () => {
    if (!editingTask) return;
    
    if (!editingTask.label.trim()) {
      Alert.alert('Error', 'Task label cannot be empty');
      return;
    }

    if (editingTask.id && tasks.find(t => t.id === editingTask.id)) {
      // Update existing task
      await updateTask(editingTask.id, editingTask.toJSON());
    } else {
      // Add new task
      await addTask(editingTask);
    }
    
    setEditingTask(null);
    setExpandedTaskId(null);
    await loadTasks();
  };

  const handleDeleteTask = async (taskId) => {
    Alert.alert(
      'Delete Task',
      'Are you sure you want to delete this task?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteTask(taskId);
            if (expandedTaskId === taskId) {
              setExpandedTaskId(null);
            }
            await loadTasks();
          },
        },
      ]
    );
  };

  const handleEditTask = (task) => {
    setEditingTask(new Task(task.toJSON()));
    setExpandedTaskId(task.id);
  };

  const TaskItem = ({ task }) => {
    const isExpanded = expandedTaskId === task.id;
    const isEditing = editingTask && editingTask.id === task.id;

    return (
      <View style={styles.taskCard}>
        {!isExpanded ? (
          <TouchableOpacity
            style={styles.taskCardHeader}
            onPress={() => handleEditTask(task)}
          >
            <View style={[styles.taskColorDot, { backgroundColor: task.color }]} />
            <View style={styles.taskCardInfo}>
              <Text style={styles.taskCardLabel}>{task.label}</Text>
              <Text style={styles.taskCardTime}>
                {task.isAllDay()
                  ? 'All Day'
                  : `${formatTime(task.startTime)} - ${formatTime(task.endTime)}`}
              </Text>
              {task.repeat && (
                <Text style={styles.taskCardRepeat}>
                  {task.repeat.type === 'daily' && 'Daily'}
                  {task.repeat.type === 'weekly' && 'Weekly'}
                  {task.repeat.type === 'monthly' && 'Monthly'}
                  {task.repeat.type === 'custom' && 'Custom'}
                </Text>
              )}
            </View>
            {task.completed && (
              <View style={styles.completedBadge}>
                <Text style={styles.completedBadgeText}>✓</Text>
              </View>
            )}
          </TouchableOpacity>
        ) : (
          <TaskEditor
            task={isEditing ? editingTask : task}
            isEditing={isEditing}
            onSave={handleSaveTask}
            onCancel={() => {
              setEditingTask(null);
              setExpandedTaskId(null);
            }}
            onDelete={() => handleDeleteTask(task.id)}
            onChange={(updates) => {
              if (isEditing) {
                setEditingTask(new Task({ ...editingTask.toJSON(), ...updates }));
              } else {
                handleEditTask(new Task({ ...task.toJSON(), ...updates }));
              }
            }}
          />
        )}
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <TouchableOpacity onPress={handlePrevDay} style={styles.navButton}>
          <Text style={styles.navButtonText}>‹</Text>
        </TouchableOpacity>
        <View style={styles.dateContainer}>
          <Text style={styles.dateText}>{formatDate(selectedDate)}</Text>
        </View>
        <TouchableOpacity onPress={handleNextDay} style={styles.navButton}>
          <Text style={styles.navButtonText}>›</Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        style={styles.scrollView}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {tasks.map(task => (
          <TaskItem key={task.id} task={task} />
        ))}
        {tasks.length === 0 && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateText}>No tasks for this day</Text>
            <Text style={styles.emptyStateSubtext}>
              Tap + to add a new task
            </Text>
          </View>
        )}
      </ScrollView>

      <TouchableOpacity style={styles.addButton} onPress={handleAddTask}>
        <Text style={styles.addButtonText}>+</Text>
      </TouchableOpacity>

      {editingTask && !tasks.find(t => t.id === editingTask.id) && (
        <Modal
          visible={true}
          animationType="slide"
          transparent={true}
          onRequestClose={() => {
            setEditingTask(null);
            setExpandedTaskId(null);
          }}
        >
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
              <ScrollView>
                <TaskEditor
                  task={editingTask}
                  isEditing={true}
                  onSave={handleSaveTask}
                  onCancel={() => {
                    setEditingTask(null);
                    setExpandedTaskId(null);
                  }}
                  onDelete={() => {
                    setEditingTask(null);
                    setExpandedTaskId(null);
                  }}
                  onChange={(updates) => {
                    setEditingTask(new Task({ ...editingTask.toJSON(), ...updates }));
                  }}
                />
              </ScrollView>
            </View>
          </View>
        </Modal>
      )}
    </SafeAreaView>
  );
};

const TaskEditor = ({ task, isEditing, onSave, onCancel, onDelete, onChange }) => {
  const [label, setLabel] = useState(task.label);
  const [startTime, setStartTime] = useState(task.startTime || '');
  const [endTime, setEndTime] = useState(task.endTime || '');
  const [isAllDay, setIsAllDay] = useState(task.isAllDay());
  const [color, setColor] = useState(task.color);
  const [repeatType, setRepeatType] = useState(task.repeat?.type || null);

  const handleSave = () => {
    const updates = {
      label,
      startTime: isAllDay ? null : startTime,
      endTime: isAllDay ? null : endTime,
      color,
      repeat: repeatType ? { type: repeatType } : null,
    };
    onChange(updates);
    onSave();
  };

  return (
    <View style={styles.editor}>
      <View style={styles.editorHeader}>
        <Text style={styles.editorTitle}>
          {isEditing ? 'Edit Task' : 'Task Details'}
        </Text>
        {!isEditing && onDelete && (
          <TouchableOpacity onPress={onDelete} style={styles.deleteButton}>
            <Text style={styles.deleteButtonText}>Delete</Text>
          </TouchableOpacity>
        )}
      </View>

      <View style={styles.editorSection}>
        <Text style={styles.editorLabel}>Label</Text>
        <TextInput
          style={styles.editorInput}
          value={label}
          onChangeText={setLabel}
          placeholder="Task name"
          editable={isEditing}
        />
      </View>

      <View style={styles.editorSection}>
        <View style={styles.checkboxRow}>
          <TouchableOpacity
            style={styles.checkbox}
            onPress={() => {
              if (isEditing) {
                setIsAllDay(!isAllDay);
                if (!isAllDay) {
                  setStartTime('');
                  setEndTime('');
                }
              }
            }}
          >
            <View style={[styles.checkboxBox, isAllDay && styles.checkboxChecked]}>
              {isAllDay && <Text style={styles.checkboxCheck}>✓</Text>}
            </View>
            <Text style={styles.checkboxLabel}>All Day</Text>
          </TouchableOpacity>
        </View>
      </View>

      {!isAllDay && (
        <>
          <View style={styles.editorSection}>
            <Text style={styles.editorLabel}>Start Time</Text>
            <TextInput
              style={styles.editorInput}
              value={startTime}
              onChangeText={setStartTime}
              placeholder="HH:mm (e.g., 09:00)"
              editable={isEditing}
            />
          </View>

          <View style={styles.editorSection}>
            <Text style={styles.editorLabel}>End Time</Text>
            <TextInput
              style={styles.editorInput}
              value={endTime}
              onChangeText={setEndTime}
              placeholder="HH:mm (e.g., 17:00)"
              editable={isEditing}
            />
          </View>
        </>
      )}

      <View style={styles.editorSection}>
        <Text style={styles.editorLabel}>Color</Text>
        <View style={styles.colorPicker}>
          {COLORS.map(c => (
            <TouchableOpacity
              key={c}
              style={[
                styles.colorOption,
                { backgroundColor: c },
                color === c && styles.colorOptionSelected,
              ]}
              onPress={() => isEditing && setColor(c)}
            />
          ))}
        </View>
      </View>

      <View style={styles.editorSection}>
        <Text style={styles.editorLabel}>Repeat</Text>
        <View style={styles.repeatOptions}>
          {['daily', 'weekly', 'monthly'].map(type => (
            <TouchableOpacity
              key={type}
              style={[
                styles.repeatOption,
                repeatType === type && styles.repeatOptionSelected,
              ]}
              onPress={() => isEditing && setRepeatType(repeatType === type ? null : type)}
            >
              <Text
                style={[
                  styles.repeatOptionText,
                  repeatType === type && styles.repeatOptionTextSelected,
                ]}
              >
                {type.charAt(0).toUpperCase() + type.slice(1)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {isEditing && (
        <View style={styles.editorActions}>
          <TouchableOpacity style={styles.cancelButton} onPress={onCancel}>
            <Text style={styles.cancelButtonText}>Cancel</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.saveButton} onPress={handleSave}>
            <Text style={styles.saveButtonText}>Save</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
};

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
    borderBottomColor: '#E5E7EB',
  },
  navButton: {
    width: 44,
    height: 44,
    justifyContent: 'center',
    alignItems: 'center',
  },
  navButtonText: {
    fontSize: 32,
    color: '#3B82F6',
    fontWeight: '300',
  },
  dateContainer: {
    flex: 1,
    alignItems: 'center',
  },
  dateText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#111827',
  },
  scrollView: {
    flex: 1,
  },
  taskCard: {
    backgroundColor: '#FFFFFF',
    marginHorizontal: 20,
    marginVertical: 8,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E5E7EB',
    overflow: 'hidden',
  },
  taskCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
  },
  taskColorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 12,
  },
  taskCardInfo: {
    flex: 1,
  },
  taskCardLabel: {
    fontSize: 16,
    fontWeight: '500',
    color: '#111827',
    marginBottom: 4,
  },
  taskCardTime: {
    fontSize: 14,
    color: '#6B7280',
  },
  taskCardRepeat: {
    fontSize: 12,
    color: '#9CA3AF',
    marginTop: 2,
  },
  completedBadge: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#10B981',
    justifyContent: 'center',
    alignItems: 'center',
  },
  completedBadgeText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  editor: {
    padding: 20,
  },
  editorHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  editorTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#111827',
  },
  editorSection: {
    marginBottom: 20,
  },
  editorLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: '#6B7280',
    marginBottom: 8,
  },
  editorInput: {
    borderWidth: 1,
    borderColor: '#D1D5DB',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#FFFFFF',
  },
  checkboxRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkboxBox: {
    width: 24,
    height: 24,
    borderWidth: 2,
    borderColor: '#D1D5DB',
    borderRadius: 6,
    marginRight: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkboxChecked: {
    backgroundColor: '#3B82F6',
    borderColor: '#3B82F6',
  },
  checkboxCheck: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  checkboxLabel: {
    fontSize: 16,
    color: '#111827',
  },
  colorPicker: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  colorOption: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  colorOptionSelected: {
    borderColor: '#111827',
    borderWidth: 3,
  },
  repeatOptions: {
    flexDirection: 'row',
    gap: 8,
  },
  repeatOption: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#D1D5DB',
    backgroundColor: '#FFFFFF',
  },
  repeatOptionSelected: {
    backgroundColor: '#3B82F6',
    borderColor: '#3B82F6',
  },
  repeatOptionText: {
    fontSize: 14,
    color: '#6B7280',
    fontWeight: '500',
  },
  repeatOptionTextSelected: {
    color: '#FFFFFF',
  },
  editorActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 12,
    marginTop: 20,
  },
  cancelButton: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#D1D5DB',
  },
  cancelButtonText: {
    fontSize: 16,
    color: '#6B7280',
    fontWeight: '500',
  },
  saveButton: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#3B82F6',
  },
  saveButtonText: {
    fontSize: 16,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  deleteButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    backgroundColor: '#FEE2E2',
  },
  deleteButtonText: {
    fontSize: 14,
    color: '#EF4444',
    fontWeight: '500',
  },
  addButton: {
    position: 'absolute',
    bottom: 30,
    right: 30,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#3B82F6',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  addButtonText: {
    fontSize: 32,
    color: '#FFFFFF',
    fontWeight: '300',
    lineHeight: 32,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 60,
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
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '90%',
  },
});

export default TasksScreen;

