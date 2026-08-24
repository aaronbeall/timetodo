import React, { useMemo } from 'react';
import { View } from 'react-native';
import Svg, { Circle, Path, G } from 'react-native-svg';
import { colors } from '../theme';
import type { Task } from '../types';

const FULL_DAY_MINUTES = 24 * 60;

function minutesToAngle(minutes: number) {
  return (minutes / FULL_DAY_MINUTES) * 360 - 90;
}

function polarToCartesian(
  cx: number,
  cy: number,
  r: number,
  angleDeg: number
) {
  const rad = (angleDeg * Math.PI) / 180;
  return {
    x: cx + r * Math.cos(rad),
    y: cy + r * Math.sin(rad),
  };
}

function arcPath(
  cx: number,
  cy: number,
  rInner: number,
  rOuter: number,
  startAngle: number,
  endAngle: number
) {
  const startOuter = polarToCartesian(cx, cy, rOuter, startAngle);
  const endOuter = polarToCartesian(cx, cy, rOuter, endAngle);
  const startInner = polarToCartesian(cx, cy, rInner, endAngle);
  const endInner = polarToCartesian(cx, cy, rInner, startAngle);

  const largeArc = endAngle - startAngle <= 180 ? '0' : '1';

  return [
    `M ${startOuter.x} ${startOuter.y}`,
    `A ${rOuter} ${rOuter} 0 ${largeArc} 1 ${endOuter.x} ${endOuter.y}`,
    `L ${startInner.x} ${startInner.y}`,
    `A ${rInner} ${rInner} 0 ${largeArc} 0 ${endInner.x} ${endInner.y}`,
    'Z',
  ].join(' ');
}

type NormalizedTask = Task & {
  _layerIndex: number;
  _layerCount: number;
};

function normalizeTasks(tasks: Task[]): NormalizedTask[] {
  // Convert tasks into layers so that overlapping tasks share total thickness.
  // Simple greedy layering: sort by start, place in first non-overlapping layer.
  const sorted = [...tasks].sort(
    (a, b) => a.startMinutes - b.startMinutes || a.endMinutes - b.endMinutes
  );

  const layers: Task[][] = [];

  sorted.forEach((task) => {
    let placed = false;
    for (const layer of layers) {
      const last = layer[layer.length - 1];
      if (task.startMinutes >= last.endMinutes) {
        layer.push(task);
        placed = true;
        break;
      }
    }
    if (!placed) {
      layers.push([task]);
    }
  });

  // Flatten with layer index
  const flat: NormalizedTask[] = [];
  layers.forEach((layer, layerIndex) => {
    layer.forEach((t) =>
      flat.push({
        ...t,
        _layerIndex: layerIndex,
        _layerCount: layers.length,
      })
    );
  });
  return flat;
}

export function RadialClock({
  size = 320,
  trackThickness = 26,
  innerPadding = 26,
  tasks = [],
  nowMinutes,
}: {
  size?: number;
  trackThickness?: number;
  innerPadding?: number;
  tasks?: Task[];
  nowMinutes: number;
}) {
  const radius = size / 2;
  const clockRadius = radius - innerPadding - trackThickness;

  const normalizedTasks = useMemo(() => normalizeTasks(tasks), [tasks]);

  const minuteAngle = minutesToAngle(nowMinutes);

  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size}>
        <G>
          <Circle
            cx={radius}
            cy={radius}
            r={clockRadius}
            fill={colors.surface}
            stroke={colors.accentSoft}
            strokeWidth={1}
          />

          {/** Filled arc from midnight to now */}
          <Path
            d={arcPath(
              radius,
              radius,
              clockRadius - 8,
              clockRadius + 4,
              -90,
              minuteAngle
            )}
            fill={colors.accentSoft}
          />

          {/** Outer track background */}
          <Circle
            cx={radius}
            cy={radius}
            r={clockRadius + trackThickness / 2 + 6}
            stroke={colors.surfaceSoft}
            strokeWidth={trackThickness + 4}
            fill="none"
            strokeLinecap="round"
          />

          {/** Task arcs */}
          {normalizedTasks.map((task) => {
            const { startMinutes, endMinutes, color, id, active } = task;
            const startAngle = minutesToAngle(startMinutes);
            const endAngle = minutesToAngle(endMinutes);

            const totalThickness = trackThickness;
            const perLayer = totalThickness / task._layerCount;
            const inset = perLayer * task._layerIndex;
            const rInner =
              clockRadius + 6 + inset - totalThickness / 2 + perLayer * 0.1;
            const rOuter = rInner + perLayer * 0.8;

            const path = arcPath(
              radius,
              radius,
              rInner,
              rOuter,
              startAngle,
              endAngle
            );

            return (
              <Path
                key={id}
                d={path}
                fill={color}
                opacity={active ? 0.95 : 0.6}
              />
            );
          })}

          {/** Clock arm */}
          <Path
            d={`M ${radius} ${radius} L ${
              polarToCartesian(radius, radius, clockRadius + trackThickness / 2, minuteAngle).x
            } ${
              polarToCartesian(radius, radius, clockRadius + trackThickness / 2, minuteAngle).y
            }`}
            stroke={colors.accent}
            strokeWidth={3}
            strokeLinecap="round"
          />

          <Circle
            cx={radius}
            cy={radius}
            r={5}
            fill={colors.accent}
            stroke={colors.background}
            strokeWidth={2}
          />
        </G>
      </Svg>
    </View>
  );
}
