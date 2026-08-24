import React, { useMemo } from 'react';
import {
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  FlatList,
  TouchableOpacity,
  LayoutAnimation,
  Platform,
  UIManager,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { useNavigation } from '@react-navigation/native';
import { RadialClock } from '../components/RadialClock';
import { useNowMinutes } from '../hooks/useNowMinutes';
import { useTaskActivitySounds } from '../hooks/useTaskActivitySounds';
import { colors, spacing, typography, radius } from '../theme';
import { useTasks } from '../state/TaskStore';
import type { Task } from '../types';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

export const MainScreen: React.FC = () => {
  const navigation = useNavigation();
  const nowMinutes = useNowMinutes();
  const { tasks } = useTasks();

  const allTasks: Task[] = useMemo(
    () => Object.values(tasks).sort((a, b) => a.startMinutes - b.startMinutes),
    [tasks]
  );

  const tasksWithActive: Task[] = useMemo(() => {
    return allTasks.map((t): Task => ({
      ...t,
      active:
        !t.paused &&
        nowMinutes >= t.startMinutes &&
        nowMinutes <= t.endMinutes,
    }));
  }, [allTasks, nowMinutes]);

  const activeTasks = tasksWithActive.filter((t) => t.active);

  useTaskActivitySounds(tasksWithActive, nowMinutes);

  const handlePlanTask = () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    navigation.navigate('Tasks' as never);
  };

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar style="light" />
      <View style={styles.root}>
        <View style={styles.header}>
          <View>
            <Text style={styles.appTitle}>TimeTodo</Text>
            <Text style={styles.appSubtitle}>Shape your day by time, not lists.</Text>
          </View>
        </View>

        <View style={styles.clockCard}>
          <RadialClock tasks={tasksWithActive} nowMinutes={nowMinutes} />
        </View>

        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>
            {activeTasks.length ? 'Now' : 'Up next'}
          </Text>
        </View>

        <FlatList<Task>
          data={activeTasks.length ? activeTasks : tasksWithActive}
          keyExtractor={(item) => item.id}
          contentContainerStyle={
            activeTasks.length ? undefined : styles.upNextContainer
          }
          renderItem={({ item }) => {
            return (
              <View style={[styles.taskRow, { borderColor: item.color + '55' }]}>
                <View style={[styles.colorDot, { backgroundColor: item.color }]} />
                <View style={{ flex: 1 }}>
                  <Text style={styles.taskName}>{item.name}</Text>
                  <Text style={styles.taskTime}>
                    {formatMinutes(item.startMinutes)} — {formatMinutes(item.endMinutes)}
                  </Text>
                </View>
                {item.active ? (
                  <View style={styles.actions}>
                    <TouchableOpacity style={styles.secondaryButton}>
                      <Text style={styles.secondaryButtonText}>Snooze</Text>
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.primaryButton}>
                      <Text style={styles.primaryButtonText}>Done</Text>
                    </TouchableOpacity>
                  </View>
                ) : null}
              </View>
            );
          }}
        />

        <View style={styles.footer}>
          <TouchableOpacity style={styles.addTaskButton} onPress={handlePlanTask}>
            <Text style={styles.addTaskLabel}>Plan a task</Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

function formatMinutes(m: number) {
  const h = Math.floor(m / 60);
  const mm = Math.floor(m % 60)
    .toString()
    .padStart(2, '0');
  return `${h}:${mm}`;
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
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  appTitle: {
    ...typography.title,
    color: colors.textPrimary,
  },
  appSubtitle: {
    ...typography.subtitle,
    color: colors.textSecondary,
    marginTop: 4,
  },
  clockCard: {
    backgroundColor: colors.surface,
    borderRadius: radius.xl,
    paddingVertical: spacing.lg,
    alignItems: 'center',
    marginBottom: spacing.lg,
    shadowColor: '#000',
    shadowOpacity: 0.35,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 16 },
    elevation: 8,
  },
  sectionHeader: {
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    ...typography.subtitle,
    color: colors.textMuted,
  },
  taskRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    gap: spacing.md,
  },
  colorDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  taskName: {
    ...typography.body,
    color: colors.textPrimary,
  },
  taskTime: {
    fontSize: 13,
    color: colors.textMuted,
    marginTop: 2,
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  secondaryButton: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    backgroundColor: colors.surfaceSoft,
  },
  secondaryButtonText: {
    fontSize: 13,
    color: colors.textSecondary,
  },
  primaryButton: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    backgroundColor: colors.accent,
  },
  primaryButtonText: {
    fontSize: 13,
    color: 'white',
    fontWeight: '500',
  },
  upNextContainer: {
    paddingBottom: spacing.lg,
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


