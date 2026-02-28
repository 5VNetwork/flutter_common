import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Returns current time. Overridable for testing.
typedef NowProvider = DateTime Function();

/// A class that periodically runs a function with persistence of last run time.
///
/// The class uses SharedPreferences to track the last successful run time.
/// When started, it calculates the initial delay based on the last run time:
/// - If the period has already passed, the task runs immediately
/// - Otherwise, it waits for the remaining time until the next scheduled run
///
/// Example:
/// ```dart
/// final periodicTask = PeriodicTask(
///   sharedPreferences: prefs,
///   task: () async {
///     // Your task logic here
///     print('Task executed');
///   },
///   period: Duration(hours: 24),
///   lastRunKey: 'myTask_lastRun',
/// );
///
/// periodicTask.start();
/// // ... later
/// periodicTask.setPeriod(Duration(hours: 12)); // Change interval dynamically
/// // ... later
/// periodicTask.stop();
/// ```
class PeriodicTask {
  final SharedPreferences _prefs;
  final Future<void> Function() _task;
  Duration _period;
  final String _lastRunKey;
  Timer? _timer;

  /// Creates a new PeriodicTask instance.
  ///
  /// [sharedPreferences] - The SharedPreferences instance to store last run time
  /// [task] - The async function to execute periodically
  /// [period] - The duration between task executions
  /// [lastRunKey] - The key to use in SharedPreferences for storing last run time
  PeriodicTask({
    required SharedPreferences sharedPreferences,
    required Future<void> Function() task,
    required Duration period,
    required String lastRunKey,
  }) : _prefs = sharedPreferences,
       _task = task,
       _period = period,
       _lastRunKey = lastRunKey;

  /// Starts the periodic task execution.
  ///
  /// Calculates the initial delay based on the last run time stored in
  /// SharedPreferences. If the period has already passed, runs immediately.
  void start() {
    if (_timer != null) {
      // Already running
      return;
    }

    _scheduleNextRun();
  }

  /// Stops the periodic task execution.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Checks if the task is currently running.
  bool get isRunning => _timer != null;

  /// Gets the current period duration.
  Duration get period => _period;

  /// Sets a new period duration for the task.
  ///
  /// If the task is currently running, it will be rescheduled based on the
  /// new period and the last run time.
  ///
  /// [newPeriod] - The new duration between task executions
  void setPeriod(Duration newPeriod) {
    if (newPeriod.isNegative) {
      throw ArgumentError('Period cannot be negative');
    }

    final wasRunning = _timer != null;
    _period = newPeriod;

    // If running, reschedule with the new period
    if (wasRunning) {
      _timer?.cancel();
      _scheduleNextRun();
    }
  }

  /// Calculates the delay until the next run should occur.
  ///
  /// Returns [Duration.zero] if the period has already passed since last run,
  /// otherwise returns the remaining time until the next scheduled run.
  Duration _calculateInitialDelay() {
    final lastRunTimestamp = _prefs.getInt(_lastRunKey);
    if (lastRunTimestamp == null) {
      // Never run before, run immediately
      return Duration.zero;
    }

    final lastRun = DateTime.fromMillisecondsSinceEpoch(lastRunTimestamp);
    final now = DateTime.now();
    final timeSinceLastRun = now.difference(lastRun);

    if (timeSinceLastRun >= _period) {
      // Period has passed, run immediately
      return Duration.zero;
    }

    // Calculate remaining time until next run
    return _period - timeSinceLastRun;
  }

  /// Schedules the next run of the task.
  void _scheduleNextRun() {
    final delay = _calculateInitialDelay();

    _timer = Timer(delay, () {
      _executeTask();
    });
  }

  /// Executes the task and schedules the next run.
  Future<void> _executeTask() async {
    final taskStartTime = DateTime.now();

    try {
      await _task();
      // Task completed successfully, save the timestamp
      await _prefs.setInt(_lastRunKey, taskStartTime.millisecondsSinceEpoch);
    } catch (e) {
      // Task failed, don't update the last run time
      // The next run will still be scheduled based on the previous successful run
    }

    // Schedule the next periodic run
    // Cancel the current timer and create a periodic one
    if (_timer != null) {
      _timer?.cancel();
      _timer = Timer.periodic(_period, (_) => _executeTask());
    }
  }

  /// Disposes of the periodic task, canceling any running timers.
  void dispose() {
    stop();
  }
}

/// Schedule frequency for ScheduledTask.
enum ScheduleFrequency {
  /// Run daily at the specified time.
  daily,

  /// Run weekly on the specified day of week at the specified time.
  weekly,

  /// Run monthly on the specified day of month at the specified time.
  monthly,
}

/// A class that runs a task at a specific time each day (like a cron job).
///
/// The class uses SharedPreferences to track the last successful run time.
/// When started, it calculates the initial delay until the next scheduled time.
/// If the last run time is before the scheduled time, it will run immediately.
/// If the last run time is after the scheduled time, it will run at the next scheduled time.
/// Supports daily, weekly, and monthly schedules.
///
/// Example (daily):
/// ```dart
/// final scheduledTask = ScheduledTask(
///   sharedPreferences: prefs,
///   task: () async {
///     print('Task executed at 8 AM Beijing time');
///   },
///   hour: 8,
///   minute: 0,
///   timeZone: 8, // UTC+8 (Beijing time)
///   lastRunKey: 'myTask_lastRun',
/// );
/// ```
///
/// Example (weekly):
/// ```dart
/// final weeklyTask = ScheduledTask(
///   sharedPreferences: prefs,
///   task: () async {
///     print('Task executed every Monday at 8 AM');
///   },
///   hour: 8,
///   minute: 0,
///   frequency: ScheduleFrequency.weekly,
///   dayOfWeek: DateTime.monday,
///   timeZone: 0, // UTC
///   lastRunKey: 'weeklyTask_lastRun',
/// );
/// ```
///
/// Example (monthly):
/// ```dart
/// final monthlyTask = ScheduledTask(
///   sharedPreferences: prefs,
///   task: () async {
///     print('Task executed on the 1st of every month at 8 AM');
///   },
///   hour: 8,
///   minute: 0,
///   frequency: ScheduleFrequency.monthly,
///   dayOfMonth: 1,
///   timeZone: 0, // UTC
///   lastRunKey: 'monthlyTask_lastRun',
/// );
/// ```
class ScheduledTask {
  final SharedPreferences _prefs;
  final Future<void> Function() _task;
  final int _hour;
  final int _minute;
  final ScheduleFrequency _frequency;
  final int? _dayOfWeek; // 1-7 (Monday-Sunday) for weekly
  final int? _dayOfMonth; // 1-31 for monthly
  final int _timeZone; // UTC offset in hours (e.g., 8 for UTC+8, -5 for UTC-5)
  final String _lastRunKey;
  final NowProvider _now;
  Timer? _timer;

  /// Creates a new ScheduledTask instance.
  ///
  /// [sharedPreferences] - The SharedPreferences instance to store last run time
  /// [task] - The async function to execute at the scheduled time
  /// [hour] - The hour of day (0-23) when the task should run
  /// [minute] - The minute of the hour (0-59) when the task should run
  /// [frequency] - The schedule frequency (daily, weekly, or monthly). Defaults to daily.
  /// [dayOfWeek] - The day of week (1-7, where 1=Monday, 7=Sunday) for weekly schedules.
  ///   Required if frequency is weekly.
  /// [dayOfMonth] - The day of month (1-31) for monthly schedules.
  ///   Required if frequency is monthly.
  /// [timeZone] - The UTC offset in hours (e.g., 8 for UTC+8 Beijing time, -5 for UTC-5 EST).
  ///   Defaults to 0 (UTC). Range is typically -12 to +14.
  /// [lastRunKey] - The key to use in SharedPreferences for storing last run time
  /// [now] - Optional provider for current time. Used for deterministic testing.
  ScheduledTask({
    required SharedPreferences sharedPreferences,
    required Future<void> Function() task,
    required int hour,
    int minute = 0,
    ScheduleFrequency frequency = ScheduleFrequency.daily,
    int? dayOfWeek,
    int? dayOfMonth,
    int timeZone = 0,
    required String lastRunKey,
    NowProvider? now,
  }) : _prefs = sharedPreferences,
       _task = task,
       _hour = hour,
       _minute = minute,
       _frequency = frequency,
       _dayOfWeek = dayOfWeek,
       _dayOfMonth = dayOfMonth,
       _timeZone = timeZone,
       _lastRunKey = lastRunKey,
       _now = now ?? DateTime.now {
    if (hour < 0 || hour > 23) {
      throw ArgumentError('Hour must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError('Minute must be between 0 and 59');
    }
    if (frequency == ScheduleFrequency.weekly) {
      if (dayOfWeek == null) {
        throw ArgumentError('dayOfWeek is required for weekly schedules');
      }
      if (dayOfWeek < 1 || dayOfWeek > 7) {
        throw ArgumentError(
          'dayOfWeek must be between 1 (Monday) and 7 (Sunday)',
        );
      }
    }
    if (frequency == ScheduleFrequency.monthly) {
      if (dayOfMonth == null) {
        throw ArgumentError('dayOfMonth is required for monthly schedules');
      }
      if (dayOfMonth < 1 || dayOfMonth > 31) {
        throw ArgumentError('dayOfMonth must be between 1 and 31');
      }
    }
  }

  /// Starts the scheduled task execution.
  ///
  /// Calculates the initial delay until the next scheduled time based on the
  /// last run time stored in SharedPreferences.
  void start() {
    if (_timer != null) {
      // Already running
      return;
    }

    _scheduleNextRun();
  }

  /// Stops the scheduled task execution.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Checks if the task is currently running.
  bool get isRunning => _timer != null;

  /// Gets the scheduled hour.
  int get hour => _hour;

  /// Gets the scheduled minute.
  int get minute => _minute;

  /// Gets the schedule frequency.
  ScheduleFrequency get frequency => _frequency;

  /// Gets the day of week (1-7, Monday-Sunday) for weekly schedules.
  int? get dayOfWeek => _dayOfWeek;

  /// Gets the day of month (1-31) for monthly schedules.
  int? get dayOfMonth => _dayOfMonth;

  /// Gets the UTC offset in hours.
  int get timeZone => _timeZone;

  /// Calculates the delay until the next scheduled run time.
  ///
  /// Returns [Duration.zero] if the scheduled time has passed (never run or missed),
  /// so the task runs immediately. Otherwise returns the delay until the next run.
  Duration _calculateNextRunDelay() {
    final nowUtc = _now().toUtc();
    final offsetHours = _timeZone;
    final targetTimeNow = nowUtc.add(Duration(hours: offsetHours));

    late DateTime scheduledThisPeriod;
    late DateTime previousScheduled;
    late DateTime nextScheduled;

    switch (_frequency) {
      case ScheduleFrequency.daily:
        scheduledThisPeriod = _scheduledDailyFor(targetTimeNow);
        previousScheduled = _scheduledDailyFor(
          targetTimeNow.subtract(const Duration(days: 1)),
        );
        if (targetTimeNow.isBefore(scheduledThisPeriod)) {
          nextScheduled = scheduledThisPeriod;
        } else {
          nextScheduled = _scheduledDailyFor(
            targetTimeNow.add(const Duration(days: 1)),
          );
        }
        break;
      case ScheduleFrequency.weekly:
        scheduledThisPeriod = _scheduledWeeklyForWeek(targetTimeNow);
        previousScheduled = _scheduledWeeklyForWeek(
          targetTimeNow.subtract(const Duration(days: 7)),
        );
        if (targetTimeNow.isBefore(scheduledThisPeriod)) {
          nextScheduled = scheduledThisPeriod;
        } else {
          nextScheduled = _scheduledWeeklyForWeek(
            targetTimeNow.add(const Duration(days: 7)),
          );
        }
        break;
      case ScheduleFrequency.monthly:
        scheduledThisPeriod = _scheduledMonthlyFor(targetTimeNow);
        previousScheduled = _scheduledMonthlyFor(
          _subtractOneMonth(targetTimeNow),
        );
        if (targetTimeNow.isBefore(scheduledThisPeriod)) {
          nextScheduled = scheduledThisPeriod;
        } else {
          nextScheduled = _scheduledMonthlyFor(_addOneMonth(targetTimeNow));
        }
        break;
    }

    final lastRunTimestamp = _prefs.getInt(_lastRunKey);
    DateTime? lastRunTarget;
    if (lastRunTimestamp != null) {
      final lastRunUtc = DateTime.fromMillisecondsSinceEpoch(
        lastRunTimestamp,
      ).toUtc();
      lastRunTarget = lastRunUtc.add(Duration(hours: offsetHours));
    }

    // Never run: run immediately if scheduled time passed, else wait
    if (lastRunTarget == null) {
      if (!scheduledThisPeriod.isAfter(targetTimeNow)) {
        return Duration.zero;
      }
      final delay = scheduledThisPeriod.difference(targetTimeNow);
      return delay.isNegative ? Duration.zero : delay;
    }

    // Last scheduled time at or before "now"
    final currentPeriodHasOccurred = !scheduledThisPeriod.isAfter(
      targetTimeNow,
    );
    final lastScheduled = currentPeriodHasOccurred
        ? scheduledThisPeriod
        : previousScheduled;

    // Missed run: last run was before the last scheduled time → run immediately
    if (lastRunTarget.isBefore(lastScheduled)) {
      return Duration.zero;
    }

    // Otherwise wait until next occurrence
    final delay = nextScheduled.difference(targetTimeNow);
    return delay.isNegative ? Duration.zero : delay;
  }

  DateTime _scheduledDailyFor(DateTime dayInTargetZone) {
    return DateTime.utc(
      dayInTargetZone.year,
      dayInTargetZone.month,
      dayInTargetZone.day,
      _hour,
      _minute,
    );
  }

  DateTime _scheduledWeeklyForWeek(DateTime refInTargetZone) {
    final currentDayOfWeek = refInTargetZone.weekday;
    final targetDayOfWeek = _dayOfWeek!;
    final dayDelta = targetDayOfWeek - currentDayOfWeek;
    final scheduledDate = refInTargetZone.add(Duration(days: dayDelta));
    return DateTime.utc(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      _hour,
      _minute,
    );
  }

  DateTime _scheduledMonthlyFor(DateTime refInTargetZone) {
    var year = refInTargetZone.year;
    var month = refInTargetZone.month;
    final requestedDay = _dayOfMonth ?? 1;
    var day = requestedDay;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) day = lastDayOfMonth;
    return DateTime.utc(year, month, day, _hour, _minute);
  }

  DateTime _addOneMonth(DateTime ref) {
    var year = ref.year;
    var month = ref.month + 1;
    if (month > 12) {
      month = 1;
      year++;
    }
    return DateTime.utc(year, month, 1, ref.hour, ref.minute);
  }

  DateTime _subtractOneMonth(DateTime ref) {
    var year = ref.year;
    var month = ref.month - 1;
    if (month < 1) {
      month = 12;
      year--;
    }
    return DateTime.utc(year, month, 1, ref.hour, ref.minute);
  }

  /// Schedules the next run of the task.
  void _scheduleNextRun() {
    final delay = _calculateNextRunDelay();

    _timer = Timer(delay, () {
      _executeTask();
    });
  }

  /// Executes the task and schedules the next run.
  Future<void> _executeTask() async {
    final taskStartTime = _now();

    try {
      await _task();
      // Task completed successfully, save the timestamp
      await _prefs.setInt(_lastRunKey, taskStartTime.millisecondsSinceEpoch);
    } catch (e) {
      // Task failed, don't update the last run time
      // The next run will still be scheduled based on the previous successful run
    }

    // Schedule the next run based on the schedule frequency
    if (_timer != null) {
      _scheduleNextRun();
    }
  }

  /// Disposes of the scheduled task, canceling any running timers.
  void dispose() {
    stop();
  }
}
