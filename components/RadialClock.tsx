import { useEffect, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import Svg, { Circle, Path, Line, Text as SvgText } from 'react-native-svg';
import Animated, {
  useSharedValue,
  useAnimatedProps,
  withTiming,
  Easing,
} from 'react-native-reanimated';

const AnimatedPath = Animated.createAnimatedComponent(Path);
const AnimatedLine = Animated.createAnimatedComponent(Line);

interface RadialClockProps {
  size?: number;
  currentTime?: Date;
}

export default function RadialClock({
  size = 320,
  currentTime = new Date(),
}: RadialClockProps) {
  const [time, setTime] = useState(currentTime);
  const rotation = useSharedValue(0);
  const arcProgress = useSharedValue(0);

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setTime(now);

      const hours = now.getHours();
      const minutes = now.getMinutes();
      const seconds = now.getSeconds();
      const totalMinutes = hours * 60 + minutes + seconds / 60;
      const angle = (totalMinutes / (24 * 60)) * 360;

      rotation.value = withTiming(angle, {
        duration: 1000,
        easing: Easing.linear,
      });
      arcProgress.value = withTiming(angle, {
        duration: 1000,
        easing: Easing.linear,
      });
    };

    updateTime();

    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  const center = size / 2;
  const clockRadius = size * 0.35;
  const hourMarkRadius = size * 0.38;

  const animatedLineProps = useAnimatedProps(() => {
    const angle = rotation.value - 90;
    const radians = (angle * Math.PI) / 180;
    const x2 = center + clockRadius * Math.cos(radians);
    const y2 = center + clockRadius * Math.sin(radians);

    return {
      x2: x2 as any,
      y2: y2 as any,
    };
  });

  const animatedArcProps = useAnimatedProps(() => {
    const angle = arcProgress.value;
    if (angle === 0) return { d: '' };

    const startAngle = -90;
    const endAngle = startAngle + angle;

    const start = polarToCartesian(center, center, clockRadius, startAngle);
    const end = polarToCartesian(center, center, clockRadius, endAngle);

    const largeArcFlag = angle > 180 ? 1 : 0;

    const d = [
      'M',
      center,
      center,
      'L',
      start.x,
      start.y,
      'A',
      clockRadius,
      clockRadius,
      0,
      largeArcFlag,
      1,
      end.x,
      end.y,
      'Z',
    ].join(' ');

    return { d };
  });

  const renderHourMarks = () => {
    const marks = [];
    for (let i = 0; i < 24; i++) {
      const angle = (i / 24) * 360 - 90;
      const radians = (angle * Math.PI) / 180;
      const x = center + hourMarkRadius * Math.cos(radians);
      const y = center + hourMarkRadius * Math.sin(radians);

      marks.push(
        <SvgText
          key={i}
          x={x}
          y={y + 4}
          fontSize="10"
          fill="#94A3B8"
          textAnchor="middle">
          {i}
        </SvgText>
      );
    }
    return marks;
  };

  return (
    <View style={styles.container}>
      <Svg width={size} height={size}>
        <Circle
          cx={center}
          cy={center}
          r={clockRadius}
          fill="none"
          stroke="#E2E8F0"
          strokeWidth="2"
        />

        <AnimatedPath
          animatedProps={animatedArcProps}
          fill="#3B82F6"
          fillOpacity={0.15}
        />

        {renderHourMarks()}

        <AnimatedLine
          x1={center}
          y1={center}
          animatedProps={animatedLineProps}
          stroke="#3B82F6"
          strokeWidth="3"
          strokeLinecap="round"
        />

        <Circle cx={center} cy={center} r="6" fill="#3B82F6" />
      </Svg>
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

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
