import { useState, useRef } from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { GestureDetector, Gesture } from 'react-native-gesture-handler';
import Animated, { useSharedValue, useAnimatedStyle, withSpring, runOnJS } from 'react-native-reanimated';
import Svg, { Circle, Path, Line, G, Text as SvgText } from 'react-native-svg';

interface RadialTimePickerProps {
  startTime: string;
  endTime: string;
  onChange: (start: string, end: string) => void;
  size?: number;
  onDraggingChange?: (isDragging: boolean) => void;
}

export default function RadialTimePicker({
  startTime,
  endTime,
  onChange,
  size = 280,
  onDraggingChange,
}: RadialTimePickerProps) {
  const [dragging, setDragging] = useState<'start' | 'end' | null>(null);
  const svgContainerRef = useRef<View>(null);
  const draggingRef = useRef<'start' | 'end' | null>(null);

  const center = size / 2;
  const radius = size * 0.38;

  // Shared values for animated positions
  const startAngleValue = useSharedValue(0);
  const endAngleValue = useSharedValue(0);

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

  const getAngularDistance = (angle1: number, angle2: number): number => {
    let diff = Math.abs(angle1 - angle2);
    if (diff > 180) diff = 360 - diff;
    return diff;
  };

  const getDistance = (x1: number, y1: number, x2: number, y2: number): number => {
    return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
  };

  const startAngle = timeToAngle(startTime);
  const endAngle = timeToAngle(endTime);

  // Update shared values when times change
  startAngleValue.value = withSpring(startAngle);
  endAngleValue.value = withSpring(endAngle);

  // Animated styles for start handle
  const startHandleStyle = useAnimatedStyle(() => {
    const angleInRadians = (startAngleValue.value * Math.PI) / 180;
    const x = center + radius * Math.cos(angleInRadians) - 12;
    const y = center + radius * Math.sin(angleInRadians) - 12;
    
    return {
      position: 'absolute',
      left: x,
      top: y,
      width: 24,
      height: 24,
      borderRadius: 12,
      backgroundColor: '#10B981',
      borderWidth: 3,
      borderColor: '#FFFFFF',
    };
  });

  // Animated styles for end handle
  const endHandleStyle = useAnimatedStyle(() => {
    const angleInRadians = (endAngleValue.value * Math.PI) / 180;
    const x = center + radius * Math.cos(angleInRadians) - 12;
    const y = center + radius * Math.sin(angleInRadians) - 12;
    
    return {
      position: 'absolute',
      left: x,
      top: y,
      width: 24,
      height: 24,
      borderRadius: 12,
      backgroundColor: '#EF4444',
      borderWidth: 3,
      borderColor: '#FFFFFF',
    };
  });

  const isNearHandle = (x: number, y: number): boolean => {
    const startPoint = polarToCartesian(center, center, radius, startAngle);
    const endPoint = polarToCartesian(center, center, radius, endAngle);
    
    const distToStart = getDistance(x, y, startPoint.x, startPoint.y);
    const distToEnd = getDistance(x, y, endPoint.x, endPoint.y);
    
    // Check if touch is within 40px of either handle
    return distToStart < 40 || distToEnd < 40;
  };

  const panGesture = Gesture.Pan()
    .onBegin((e) => {
      'worklet';
      const { x, y } = e;
      
      // Calculate distance from touch point to start and end handles
      const startAngleRad = (startAngleValue.value * Math.PI) / 180;
      const endAngleRad = (endAngleValue.value * Math.PI) / 180;
      
      const startPointX = center + radius * Math.cos(startAngleRad);
      const startPointY = center + radius * Math.sin(startAngleRad);
      const endPointX = center + radius * Math.cos(endAngleRad);
      const endPointY = center + radius * Math.sin(endAngleRad);
      
      const distToStart = Math.sqrt((x - startPointX) ** 2 + (y - startPointY) ** 2);
      const distToEnd = Math.sqrt((x - endPointX) ** 2 + (y - endPointY) ** 2);

      const whichDrag = distToStart < distToEnd ? 'start' : 'end';
      runOnJS(setDragging)(whichDrag);
      runOnJS(() => {
        draggingRef.current = whichDrag;
        onDraggingChange?.(true);
      })();
    })
    .onUpdate((e) => {
      'worklet';
      if (!draggingRef.current) return;

      const { x, y } = e;
      const dx = x - center;
      const dy = y - center;
      const angle = (Math.atan2(dy, dx) * 180) / Math.PI;

      if (draggingRef.current === 'start') {
        startAngleValue.value = angle;
        runOnJS((newAngle: number) => {
          let normalizedAngle = (newAngle + 90) % 360;
          if (normalizedAngle < 0) normalizedAngle += 360;
          const totalMinutes = Math.round((normalizedAngle / 360) * 24 * 60);
          const hours = Math.floor(totalMinutes / 60) % 24;
          const minutes = totalMinutes % 60;
          const newTime = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:00`;
          onChange(newTime, endTime);
        })(angle);
      } else {
        endAngleValue.value = angle;
        runOnJS((newAngle: number) => {
          let normalizedAngle = (newAngle + 90) % 360;
          if (normalizedAngle < 0) normalizedAngle += 360;
          const totalMinutes = Math.round((normalizedAngle / 360) * 24 * 60);
          const hours = Math.floor(totalMinutes / 60) % 24;
          const minutes = totalMinutes % 60;
          const newTime = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:00`;
          onChange(startTime, newTime);
        })(angle);
      }
    })
    .onEnd(() => {
      'worklet';
      runOnJS(() => {
        draggingRef.current = null;
        setDragging(null);
        onDraggingChange?.(false);
      })();
    })
    .onFinalize(() => {
      'worklet';
      runOnJS(() => {
        draggingRef.current = null;
        setDragging(null);
        onDraggingChange?.(false);
      })();
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
      <GestureDetector gesture={panGesture}>
        <View
          ref={svgContainerRef}
          style={[styles.svgContainer, { width: size, height: size }]}>
          <Svg width={size} height={size} pointerEvents="none">
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
          </Svg>
          
          <Animated.View style={startHandleStyle} />
          <Animated.View style={endHandleStyle} />
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
  svgContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
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
