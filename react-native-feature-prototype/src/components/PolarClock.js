import React, { useEffect, useState } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import Svg, { Circle, Path, G, Text as SvgText } from 'react-native-svg';
import { getCurrentTimeAngle } from '../utils/dateUtils';

const { width } = Dimensions.get('window');
const CLOCK_SIZE = Math.min(width - 40, 350);
const CENTER = CLOCK_SIZE / 2;
const BASE_RADIUS = CLOCK_SIZE * 0.35;
const TRACK_WIDTH = 20;
const TRACK_SPACING = 8;

const PolarClock = ({ tasks = [] }) => {
  const [currentAngle, setCurrentAngle] = useState(getCurrentTimeAngle());

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentAngle(getCurrentTimeAngle());
    }, 60000); // Update every minute

    return () => clearInterval(interval);
  }, []);

  // Sort tasks by start time for proper stacking
  const sortedTasks = [...tasks]
    .filter(t => !t.isAllDay() && !t.completed)
    .sort((a, b) => {
      if (!a.startTime || !b.startTime) return 0;
      return a.startTime.localeCompare(b.startTime);
    });

  // Calculate radius for each task track
  const getTaskRadius = (index) => {
    return BASE_RADIUS + TRACK_WIDTH + (TRACK_WIDTH + TRACK_SPACING) * (index + 1);
  };

  const createArc = (startAngle, endAngle, radius) => {
    // Normalize angles
    const start = ((startAngle % 360) + 360) % 360;
    const end = ((endAngle % 360) + 360) % 360;
    
    const startRad = (start * Math.PI) / 180;
    const endRad = (end * Math.PI) / 180;
    
    const x1 = CENTER + radius * Math.cos(startRad);
    const y1 = CENTER + radius * Math.sin(startRad);
    const x2 = CENTER + radius * Math.cos(endRad);
    const y2 = CENTER + radius * Math.sin(endRad);
    
    // Calculate sweep flag and large arc flag
    let sweepAngle = end - start;
    if (sweepAngle < 0) sweepAngle += 360;
    const largeArcFlag = sweepAngle > 180 ? 1 : 0;
    const sweepFlag = 1; // Always clockwise
    
    return `M ${CENTER} ${CENTER} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArcFlag} ${sweepFlag} ${x2} ${y2} Z`;
  };

  const createHourMarkers = () => {
    const markers = [];
    for (let i = 0; i < 24; i++) {
      const angle = (i * 15) - 90; // 15 degrees per hour, -90 to start at top
      const rad = (angle * Math.PI) / 180;
      const innerRadius = BASE_RADIUS - 5;
      const outerRadius = BASE_RADIUS + 5;
      
      const x1 = CENTER + innerRadius * Math.cos(rad);
      const y1 = CENTER + innerRadius * Math.sin(rad);
      const x2 = CENTER + outerRadius * Math.cos(rad);
      const y2 = CENTER + outerRadius * Math.sin(rad);
      
      markers.push(
        <Path
          key={`marker-${i}`}
          d={`M ${x1} ${y1} L ${x2} ${y2}`}
          stroke="#E5E7EB"
          strokeWidth={1}
        />
      );
    }
    return markers;
  };

  return (
    <View style={styles.container}>
      <Svg width={CLOCK_SIZE} height={CLOCK_SIZE} viewBox={`0 0 ${CLOCK_SIZE} ${CLOCK_SIZE}`}>
        {/* Hour markers */}
        <G>{createHourMarkers()}</G>
        
        {/* Main hour track (24-hour day) */}
        <Circle
          cx={CENTER}
          cy={CENTER}
          r={BASE_RADIUS}
          fill="none"
          stroke="#F3F4F6"
          strokeWidth={TRACK_WIDTH}
        />
        
        {/* Filled portion of hour track (current time) */}
        {currentAngle > -90 && (
          <Path
            d={createArc(-90, currentAngle, BASE_RADIUS)}
            fill="#3B82F6"
            opacity={0.3}
          />
        )}
        
        {/* Task tracks */}
        {sortedTasks.map((task, index) => {
          const radius = getTaskRadius(index);
          const startAngle = task.getStartAngle();
          const endAngle = task.getEndAngle();
          
          return (
            <G key={task.id}>
              {/* Background track */}
              <Circle
                cx={CENTER}
                cy={CENTER}
                r={radius}
                fill="none"
                stroke="#F3F4F6"
                strokeWidth={TRACK_WIDTH}
              />
              {/* Task arc */}
              <Path
                d={createArc(startAngle, endAngle, radius)}
                fill={task.color}
                opacity={0.6}
              />
            </G>
          );
        })}
      </Svg>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 20,
  },
});

export default PolarClock;

