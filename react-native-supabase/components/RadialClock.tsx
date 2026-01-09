import { useEffect, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import Svg, { Circle, Path, Line, Text as SvgText } from 'react-native-svg';

interface RadialClockProps {
  size?: number;
  currentTime?: Date;
}

export default function RadialClock({
  size = 320,
  currentTime = new Date(),
}: RadialClockProps) {
  const [time, setTime] = useState(currentTime);

  useEffect(() => {
    const updateTime = () => setTime(new Date());
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  const center = size / 2;
  const clockRadius = size * 0.35;
  const hourMarkRadius = size * 0.38;

  const angle = (() => {
    const hours = time.getHours();
    const minutes = time.getMinutes();
    const seconds = time.getSeconds();
    const totalMinutes = hours * 60 + minutes + seconds / 60;
    return (totalMinutes / (24 * 60)) * 360;
  })();

  const handPosition = (() => {
    const adjustedAngle = angle - 90;
    const radians = (adjustedAngle * Math.PI) / 180;
    return {
      x2: center + clockRadius * Math.cos(radians),
      y2: center + clockRadius * Math.sin(radians),
    };
  })();

  const arcPath = (() => {
    if (angle === 0) return '';

    const startAngle = -90;
    const endAngle = startAngle + angle;

    const start = polarToCartesian(center, center, clockRadius, startAngle);
    const end = polarToCartesian(center, center, clockRadius, endAngle);

    const largeArcFlag = angle > 180 ? 1 : 0;

    return [
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
  })();

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
    <View style={[styles.container, { width: size, height: size }]}>
      <Svg width={size} height={size}>
        <Circle
          cx={center}
          cy={center}
          r={clockRadius}
          fill="none"
          stroke="#E2E8F0"
          strokeWidth="2"
        />

        <Path d={arcPath} fill="#3B82F6" fillOpacity={0.15} />

        {renderHourMarks()}

        <Line
          x1={center}
          y1={center}
          x2={handPosition.x2}
          y2={handPosition.y2}
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
