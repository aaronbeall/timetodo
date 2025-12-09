import { useState } from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { GestureDetector, Gesture } from 'react-native-gesture-handler';
import Svg, { Circle, Path, Line, G, Text as SvgText } from 'react-native-svg';

interface RadialTimePickerProps {
  startTime: string;
  endTime: string;
  onChange: (start: string, end: string) => void;
  size?: number;
}

export default function RadialTimePicker({
  startTime,
  endTime,
  onChange,
  size = 280,
}: RadialTimePickerProps) {
  const [dragging, setDragging] = useState<'start' | 'end' | null>(null);

  const center = size / 2;
  const radius = size * 0.38;

  const timeToAngle = (timeStr: string): number => {
    const [hours, minutes] = timeStr.split(':').map(Number);
    const totalMinutes = hours * 60 + minutes;
    return ((totalMinutes / (24 * 60)) * 360 - 90) % 360;
  };

  const angleToTime = (angle: number): string => {
    let normalizedAngle = (angle + 90) % 360;
    if (normalizedAngle < 0) normalizedAngle += 360;

    const totalMinutes = Math.round((normalizedAngle / 360) * 24 * 60);
    const hours = Math.floor(totalMinutes / 60) % 24;
    const minutes = totalMinutes % 60;

    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:00`;
  };

  const cartesianToAngle = (x: number, y: number): number => {
    const dx = x - center;
    const dy = y - center;
    return (Math.atan2(dy, dx) * 180) / Math.PI;
  };

  const startAngle = timeToAngle(startTime);
  const endAngle = timeToAngle(endTime);

  const gesture = Gesture.Pan()
    .onStart((e) => {
      const angle = cartesianToAngle(e.x, e.y);
      const distToStart = Math.abs(angle - startAngle);
      const distToEnd = Math.abs(angle - endAngle);

      setDragging(distToStart < distToEnd ? 'start' : 'end');
    })
    .onUpdate((e) => {
      if (!dragging) return;

      const angle = cartesianToAngle(e.x, e.y);
      const newTime = angleToTime(angle);

      if (dragging === 'start') {
        onChange(newTime, endTime);
      } else {
        onChange(startTime, newTime);
      }
    })
    .onEnd(() => {
      setDragging(null);
    });

  const renderHourMarks = () => {
    const marks = [];
    for (let i = 0; i < 24; i++) {
      const angle = (i / 24) * 360 - 90;
      const radians = (angle * Math.PI) / 180;
      const x = center + (radius + 20) * Math.cos(radians);
      const y = center + (radius + 20) * Math.sin(radians);

      if (i % 3 === 0) {
        marks.push(
          <SvgText
            key={i}
            x={x}
            y={y + 4}
            fontSize="12"
            fill="#64748B"
            fontWeight="500"
            textAnchor="middle">
            {i}
          </SvgText>
        );
      }
    }
    return marks;
  };

  const createArcPath = (): string => {
    let angle = endAngle - startAngle;
    if (angle < 0) angle += 360;

    const start = polarToCartesian(center, center, radius, startAngle);
    const end = polarToCartesian(center, center, radius, endAngle);

    const largeArcFlag = angle > 180 ? 1 : 0;

    return [
      'M',
      start.x,
      start.y,
      'A',
      radius,
      radius,
      0,
      largeArcFlag,
      1,
      end.x,
      end.y,
    ].join(' ');
  };

  const startPoint = polarToCartesian(center, center, radius, startAngle);
  const endPoint = polarToCartesian(center, center, radius, endAngle);

  return (
    <View style={styles.container}>
      <GestureDetector gesture={gesture}>
        <View>
          <Svg width={size} height={size}>
            <Circle
              cx={center}
              cy={center}
              r={radius}
              fill="none"
              stroke="#E2E8F0"
              strokeWidth="8"
            />

            <Path
              d={createArcPath()}
              fill="none"
              stroke="#3B82F6"
              strokeWidth="8"
              strokeLinecap="round"
            />

            {renderHourMarks()}

            <Circle
              cx={startPoint.x}
              cy={startPoint.y}
              r="12"
              fill="#10B981"
              stroke="#FFFFFF"
              strokeWidth="3"
            />

            <Circle
              cx={endPoint.x}
              cy={endPoint.y}
              r="12"
              fill="#EF4444"
              stroke="#FFFFFF"
              strokeWidth="3"
            />
          </Svg>
        </View>
      </GestureDetector>

      <View style={styles.timeDisplay}>
        <View style={styles.timeItem}>
          <View style={[styles.timeDot, { backgroundColor: '#10B981' }]} />
          <Text style={styles.timeLabel}>Start</Text>
          <Text style={styles.timeValue}>{formatTime(startTime)}</Text>
        </View>
        <View style={styles.timeItem}>
          <View style={[styles.timeDot, { backgroundColor: '#EF4444' }]} />
          <Text style={styles.timeLabel}>End</Text>
          <Text style={styles.timeValue}>{formatTime(endTime)}</Text>
        </View>
      </View>
    </View>
  );
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

function formatTime(timeStr: string): string {
  const [hours, minutes] = timeStr.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes.toString().padStart(2, '0')} ${period}`;
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  timeDisplay: {
    flexDirection: 'row',
    gap: 32,
    marginTop: 24,
  },
  timeItem: {
    alignItems: 'center',
  },
  timeDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginBottom: 8,
  },
  timeLabel: {
    fontSize: 12,
    color: '#64748B',
    marginBottom: 4,
  },
  timeValue: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1E293B',
  },
});
