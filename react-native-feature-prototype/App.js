import React from 'react';
import { Text, View, StyleSheet } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';
import TodayScreen from './src/screens/TodayScreen';
import TasksScreen from './src/screens/TasksScreen';

const Tab = createBottomTabNavigator();

const TabIcon = ({ label, color }) => {
  return (
    <Text style={{ fontSize: 20, color }}>
      {label === 'Today' ? '📅' : '✓'}
    </Text>
  );
};

export default function App() {
  return (
    <>
      <StatusBar style="dark" />
      <NavigationContainer>
        <Tab.Navigator
          screenOptions={{
            headerShown: false,
            tabBarActiveTintColor: '#3B82F6',
            tabBarInactiveTintColor: '#9CA3AF',
            tabBarStyle: {
              borderTopWidth: 1,
              borderTopColor: '#E5E7EB',
              paddingBottom: 8,
              paddingTop: 8,
              height: 60,
            },
            tabBarLabelStyle: {
              fontSize: 12,
              fontWeight: '500',
            },
          }}
        >
          <Tab.Screen
            name="Today"
            component={TodayScreen}
            options={{
              tabBarLabel: 'Today',
              tabBarIcon: ({ color }) => (
                <TabIcon label="Today" color={color} />
              ),
            }}
          />
          <Tab.Screen
            name="Tasks"
            component={TasksScreen}
            options={{
              tabBarLabel: 'Tasks',
              tabBarIcon: ({ color }) => (
                <TabIcon label="Tasks" color={color} />
              ),
            }}
          />
        </Tab.Navigator>
      </NavigationContainer>
    </>
  );
}

