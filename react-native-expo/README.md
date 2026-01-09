# TimeToDo

A beautiful and intuitive mobile app for managing your daily tasks with a unique polar clock visualization.

## Features

### Today Screen
- **Polar Clock Visualization**: A large 24-hour polar clock showing:
  - Current time filled in blue
  - Task tracks as concentric rings, each representing a task's time slot
  - Tasks automatically stack without overlapping
- **Task Management**:
  - **Active Tasks**: Prominently displayed tasks that are currently happening, with snooze and complete actions
  - **Upcoming Tasks**: Subtly displayed future tasks for the day, can be deleted
  - **All-Day Tasks**: Distinctly styled tasks that span the entire day

### Tasks Screen
- **Date Navigation**: Browse tasks for any day with prev/next buttons
- **Task List**: View all tasks for the selected day, including those from repeat rules
- **Task Editing**:
  - Collapsed view showing task summary
  - Expanded view for full editing:
    - Label editing
    - Color selection from 10 beautiful colors
    - Time settings (start/end or all-day)
    - Repeat options (daily, weekly, monthly)
- **Quick Actions**: Add new tasks with sensible defaults based on current time

## Getting Started

### Prerequisites
- Node.js (v14 or higher)
- npm or yarn
- Expo CLI (`npm install -g expo-cli`)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

3. Run on your device:
   - Scan the QR code with Expo Go app (iOS/Android)
   - Or press `i` for iOS simulator / `a` for Android emulator

## Project Structure

```
cursor/
├── App.js                 # Main app component with navigation
├── src/
│   ├── components/
│   │   └── PolarClock.js  # Polar clock visualization component
│   ├── models/
│   │   └── Task.js        # Task data model
│   ├── screens/
│   │   ├── TodayScreen.js # Today screen with polar clock
│   │   └── TasksScreen.js # Tasks management screen
│   └── utils/
│       ├── dateUtils.js   # Date/time formatting utilities
│       └── storage.js     # AsyncStorage wrapper for task persistence
└── package.json
```

## Technologies

- **React Native** with **Expo** - Cross-platform mobile development
- **React Navigation** - Tab navigation
- **React Native SVG** - Polar clock visualization
- **AsyncStorage** - Local data persistence
- **date-fns** - Date manipulation and formatting

## Task Features

Each task supports:
- **Label**: Custom task name
- **Timing**: Start/end time or all-day
- **Color**: 10 predefined colors for visual organization
- **Date**: Specific date assignment
- **Repeat**: Daily, weekly, monthly patterns
- **Snooze**: 15-minute delay for active tasks
- **Complete**: Mark tasks as done

## License

MIT

