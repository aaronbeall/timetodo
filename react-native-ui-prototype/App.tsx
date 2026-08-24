import React from 'react';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { TaskProvider } from './src/state/TaskStore';
import { MainScreen } from './src/screens/MainScreen';
import { TaskManagementScreen } from './src/screens/TaskManagementScreen';

export type RootStackParamList = {
  Main: undefined;
  Tasks: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

const navTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: 'transparent',
  },
};

export default function App() {
  return (
    <TaskProvider>
      <NavigationContainer theme={navTheme}>
        <Stack.Navigator
          initialRouteName="Main"
          screenOptions={{
            headerShown: false,
            animation: 'fade',
          }}
        >
          <Stack.Screen name="Main" component={MainScreen} />
          <Stack.Screen name="Tasks" component={TaskManagementScreen} />
        </Stack.Navigator>
      </NavigationContainer>
    </TaskProvider>
  );
}


