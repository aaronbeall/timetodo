import { View, StyleSheet } from 'react-native';
import Svg, { Path, G } from 'react-native-svg';
import { Task } from '@/lib/supabase';
import { ReactElement } from 'react';

interface TaskArcsProps {
  tasks: Task[];
  size?: number;
  currentTime: Date;
}

export default function TaskArcs({
  tasks,
  size = 320,
  currentTime,
}: TaskArcsProps) {
  const center = size / 2;
  const outerRadius = size * 0.46;
  const ringThickness = 24;

  const getTasksForToday = () => {
    const today = currentTime.toISOString().split('T')[0];
    const dayOfWeek = currentTime.getDay();

    return tasks.filter((task) => {
      if (task.is_paused) return false;

      const taskStart = new Date(task.start_date);
      const taskEnd = task.end_date ? new Date(task.end_date) : null;

      if (today < task.start_date) return false;
      if (taskEnd && task.end_date && today > task.end_date) return false;

      switch (task.repeat_pattern) {
        case 'none':
          return today === task.start_date;
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
  };

  const timeToMinutes = (timeStr: string): number => {
    const [hours, minutes] = timeStr.split(':').map(Number);
    return hours * 60 + minutes;
  };

  const getOverlappingGroups = () => {
    const todayTasks = getTasksForToday();
    const groups: Task[][] = [];

    todayTasks.forEach((task) => {
      const taskStart = timeToMinutes(task.start_time);
      const taskEnd = timeToMinutes(task.end_time);

      let foundGroup = false;
      for (const group of groups) {
        const hasOverlap = group.some((groupTask) => {
          const gStart = timeToMinutes(groupTask.start_time);
          const gEnd = timeToMinutes(groupTask.end_time);
          return taskStart < gEnd && taskEnd > gStart;
        });

        if (hasOverlap) {
          group.push(task);
          foundGroup = true;
          break;
        }
      }

      if (!foundGroup) {
        groups.push([task]);
      }
    });

    return groups;
  };

  const isTaskActive = (task: Task): boolean => {
    const currentMinutes =
      currentTime.getHours() * 60 + currentTime.getMinutes();
    const taskStart = timeToMinutes(task.start_time);
    const taskEnd = timeToMinutes(task.end_time);
    return currentMinutes >= taskStart && currentMinutes < taskEnd;
  };

  const renderTaskArcs = () => {
    const groups = getOverlappingGroups();
    const arcs: ReactElement[] = [];

    groups.forEach((group, groupIndex) => {
      const stackCount = group.length;
      const stackThickness = ringThickness / stackCount;

      group.forEach((task, stackIndex) => {
        const taskStart = timeToMinutes(task.start_time);
        const taskEnd = timeToMinutes(task.end_time);

        const startAngle = ((taskStart / (24 * 60)) * 360 - 90) % 360;
        const endAngle = ((taskEnd / (24 * 60)) * 360 - 90) % 360;

        const radius = outerRadius - stackIndex * stackThickness;
        const innerRadius = radius - stackThickness;

        const active = isTaskActive(task);
        const opacity = active ? 1 : 0.7;
        const strokeWidth = active ? 2 : 0;

        const arcPath = createArcPath(
          center,
          center,
          radius,
          innerRadius,
          startAngle,
          endAngle
        );

        arcs.push(
          <G key={`${task.id}-${groupIndex}-${stackIndex}`}>
            <Path
              d={arcPath}
              fill={task.color}
              fillOpacity={opacity}
              stroke={active ? '#FFFFFF' : 'none'}
              strokeWidth={strokeWidth}
            />
          </G>
        );
      });
    });

    return arcs;
  };

  return (
    <View style={styles.container}>
      <Svg
        width={size}
        height={size}
        style={StyleSheet.absoluteFill}
        pointerEvents="none">
        {renderTaskArcs()}
      </Svg>
    </View>
  );
}

function createArcPath(
  cx: number,
  cy: number,
  outerRadius: number,
  innerRadius: number,
  startAngle: number,
  endAngle: number
): string {
  const startOuter = polarToCartesian(cx, cy, outerRadius, startAngle);
  const endOuter = polarToCartesian(cx, cy, outerRadius, endAngle);
  const startInner = polarToCartesian(cx, cy, innerRadius, startAngle);
  const endInner = polarToCartesian(cx, cy, innerRadius, endAngle);

  let angle = endAngle - startAngle;
  if (angle < 0) angle += 360;
  const largeArcFlag = angle > 180 ? 1 : 0;

  const d = [
    'M',
    startOuter.x,
    startOuter.y,
    'A',
    outerRadius,
    outerRadius,
    0,
    largeArcFlag,
    1,
    endOuter.x,
    endOuter.y,
    'L',
    endInner.x,
    endInner.y,
    'A',
    innerRadius,
    innerRadius,
    0,
    largeArcFlag,
    0,
    startInner.x,
    startInner.y,
    'Z',
  ].join(' ');

  return d;
}

function polarToCartesian(
  centerX: number,
  centerY: number,
  radius: number,
  angleInDegrees: number
) {
  const angleInRadians = (angleInDegrees * Math.PI) / 180;
  return {
    x: centerX + radius * Math.cos(angleInRadians),
    y: centerY + radius * Math.sin(angleInRadians),
  };
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
