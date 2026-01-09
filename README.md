## Time To Do!

### WORK IN PROGRESS ###

<img width="389" height="849" alt="image" src="https://github.com/user-attachments/assets/4cd2e4cb-78b0-4197-8f0c-c963a3f23920" />


A beautiful and slick mobile app called TimeToDo:
* There two main screens: Today, and Tasks
* Today screen is where the app shines:
  * A large polar clock with single hour track representing the 24 hours in a day is in the middle, filled up to the time of day
  * Tasks for the day are shown like additional polar clock tracks, with the begin and end angle representing the start and stop time of the task
  * The task polar tracks stack in concentric radius, do not overlap, but can share the same track if times don't overlap
  * Each task has a label, start and end (or all day -- full circle), color, date and repeat options, can be snoozed and completed
  * Below the clock is a simple list of active and upcoming tasks for the day:
    * Tasks that are active (the time of day intersects their start and stop) are shown more prominently, can be snoozed (which moves them forward by 15 minutes) and completed
    * Upcoming tasks for the day are shown more subtly, and can be deleted
    * All day tasks are shown at the very bottom of the list using distinct styling and cannot be snoozed or completed
    * A separate list of completed tasks (struck out) for the day is shown below
    * An + add task button is on this screen
* The Tasks screen lets you manage your tasks, and works like a typical alarm app:
  * At the top is the date, and Prev/Next day buttons
  * A list of tasks for the day is shown, including those that are assigned to the day due to repeat rules
  * Each task is collapsed into simple view mode (color, label, timing, repeats) and can be expanded for editing
  * Expanded task lets you edit label, color, timing, repeat options (daily, weekly, mothly, on specific week days, every N days/weeks, etc)
  * There is + button to add a new task, which adds, expands, and focuses a new task, with sensible defaults based on the current day and time
