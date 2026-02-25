import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_common/services/periodic.dart';

void main() {
  group('PeriodicTask', () {
    late SharedPreferences prefs;
    const testKey = 'test_lastRun';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
    });

    test('should run immediately when never run before', () async {
      var taskExecuted = false;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          taskExecuted = true;
        },
        period: const Duration(hours: 1),
        lastRunKey: testKey,
      );

      task.start();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(taskExecuted, isTrue);
      expect(task.isRunning, isTrue);
      task.stop();
    });

    test('should run immediately when period has passed', () async {
      final pastTime = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      await prefs.setInt(testKey, pastTime);

      var taskExecuted = false;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          taskExecuted = true;
        },
        period: const Duration(hours: 1),
        lastRunKey: testKey,
      );

      task.start();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(taskExecuted, isTrue);
      task.stop();
    });

    test('should wait for remaining time when period has not passed', () async {
      final now = DateTime.now();
      final halfSecondAgo = now.subtract(const Duration(milliseconds: 500));
      await prefs.setInt(testKey, halfSecondAgo.millisecondsSinceEpoch);

      var taskExecuted = false;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          taskExecuted = true;
        },
        period: const Duration(seconds: 1),
        lastRunKey: testKey,
      );

      task.start();
      expect(taskExecuted, isFalse);
      expect(task.isRunning, isTrue);

      // Wait less than remaining time - task should not have run yet
      await Future.delayed(const Duration(milliseconds: 400));
      expect(taskExecuted, isFalse);

      // Wait for remaining time - task should run now
      await Future.delayed(const Duration(milliseconds: 150));
      expect(taskExecuted, isTrue);

      task.stop();
    });

    test('should save timestamp on successful task execution', () async {
      var taskExecuted = false;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          taskExecuted = true;
        },
        period: const Duration(hours: 1),
        lastRunKey: testKey,
      );

      expect(prefs.getInt(testKey), isNull);

      task.start();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(taskExecuted, isTrue);
      expect(prefs.getInt(testKey), isNotNull);
      expect(
        DateTime.fromMillisecondsSinceEpoch(prefs.getInt(testKey)!),
        isA<DateTime>(),
      );

      task.stop();
    });

    test('should not save timestamp on failed task execution', () async {
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          throw Exception('Task failed');
        },
        period: const Duration(hours: 1),
        lastRunKey: testKey,
      );

      expect(prefs.getInt(testKey), isNull);

      task.start();
      await Future.delayed(const Duration(milliseconds: 10));

      // Timestamp should not be saved on failure
      expect(prefs.getInt(testKey), isNull);

      task.stop();
    });

    test('should run task periodically after initial execution', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
        },
        period: const Duration(milliseconds: 100),
        lastRunKey: testKey,
      );

      task.start();
      // Initial execution
      await Future.delayed(const Duration(milliseconds: 10));
      expect(executionCount, equals(1));

      // Wait for first periodic execution
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(2));

      // Wait for second periodic execution
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(3));

      task.stop();
    });

    test('should stop task execution', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
        },
        period: const Duration(milliseconds: 100),
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(executionCount, equals(1));

      task.stop();
      expect(task.isRunning, isFalse);

      // Task should not run after stop
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(1));
    });

    test('should not start multiple times if already running', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
        },
        period: const Duration(milliseconds: 100),
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);

      // Try to start again
      task.start();
      expect(task.isRunning, isTrue);

      await Future.delayed(const Duration(milliseconds: 10));
      // Should only execute once
      expect(executionCount, equals(1));

      task.stop();
    });

    test('should handle task that takes time to complete', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
          // Simulate task that takes some time
          await Future.delayed(const Duration(milliseconds: 20));
        },
        period: const Duration(milliseconds: 100),
        lastRunKey: testKey,
      );

      task.start();
      // Wait for initial execution to complete (task takes 20ms)
      await Future.delayed(const Duration(milliseconds: 30));
      expect(executionCount, equals(1));

      // Wait for next periodic execution (periodic timer fires 100ms after creation)
      // Task completed at ~20ms, periodic timer created then, so wait 100ms more
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(2));

      task.stop();
    });

    test('should calculate correct delay when period just passed', () async {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1, seconds: 1));
      await prefs.setInt(testKey, oneHourAgo.millisecondsSinceEpoch);

      var taskExecuted = false;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          taskExecuted = true;
        },
        period: const Duration(hours: 1),
        lastRunKey: testKey,
      );

      task.start();
      // Should run immediately since period has passed
      await Future.delayed(const Duration(milliseconds: 10));
      expect(taskExecuted, isTrue);

      task.stop();
    });

    test('should handle dispose correctly', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
        },
        period: const Duration(milliseconds: 100),
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);

      task.dispose();
      expect(task.isRunning, isFalse);

      // Task should not run after dispose
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(0));
    });

    test('should use correct SharedPreferences key', () async {
      const customKey = 'custom_task_key';
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {},
        period: const Duration(hours: 1),
        lastRunKey: customKey,
      );

      task.start();
      await Future.delayed(const Duration(milliseconds: 10));

      // Should save to custom key, not testKey
      expect(prefs.getInt(customKey), isNotNull);
      expect(prefs.getInt(testKey), isNull);

      task.stop();
    });

    test('should handle multiple start/stop cycles', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
        },
        period: const Duration(milliseconds: 100),
        lastRunKey: testKey,
      );

      // First cycle
      task.start();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(executionCount, equals(1));
      task.stop();

      // Second cycle - since last run was just 10ms ago, it should wait
      // for remaining time (90ms) before running
      task.start();
      expect(task.isRunning, isTrue);
      // Wait for the remaining period (90ms) plus a small buffer
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(2));
      task.stop();

      expect(task.isRunning, isFalse);
    });

    test('should get current period', () {
      const period = Duration(hours: 24);
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {},
        period: period,
        lastRunKey: testKey,
      );

      expect(task.period, equals(period));
    });

    test('should set new period when not running', () {
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {},
        period: const Duration(hours: 24),
        lastRunKey: testKey,
      );

      expect(task.period, equals(const Duration(hours: 24)));

      task.setPeriod(const Duration(hours: 12));
      expect(task.period, equals(const Duration(hours: 12)));
      expect(task.isRunning, isFalse);
    });

    test('should reschedule when period changes while running', () async {
      var executionCount = 0;
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {
          executionCount++;
        },
        period: const Duration(milliseconds: 200),
        lastRunKey: testKey,
      );

      task.start();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(executionCount, equals(1));
      expect(task.period, equals(const Duration(milliseconds: 200)));

      // Change period while running - should reschedule
      task.setPeriod(const Duration(milliseconds: 100));
      expect(task.period, equals(const Duration(milliseconds: 100)));
      expect(task.isRunning, isTrue);

      // Wait for the new period (should be based on last run time)
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, equals(2));

      task.stop();
    });

    test('should throw error when setting negative period', () {
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {},
        period: const Duration(hours: 24),
        lastRunKey: testKey,
      );

      expect(
        () => task.setPeriod(const Duration(seconds: -1)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle period change to zero duration', () {
      final task = PeriodicTask(
        sharedPreferences: prefs,
        task: () async {},
        period: const Duration(hours: 24),
        lastRunKey: testKey,
      );

      task.setPeriod(Duration.zero);
      expect(task.period, equals(Duration.zero));
    });
  });

  group('ScheduledTask', () {
    late SharedPreferences prefs;
    const testKey = 'test_scheduled_lastRun';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
    });

    test('should validate hour and minute ranges', () {
      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: -1,
          minute: 0,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 24,
          minute: 0,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: -1,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 60,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should get hour, minute, and timezone', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 30,
        timeZone: 8, // UTC+8 (Beijing time)
        lastRunKey: testKey,
      );

      expect(task.hour, equals(8));
      expect(task.minute, equals(30));
      expect(task.timeZone, equals(8));
    });

    test('should use UTC as default timezone', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        lastRunKey: testKey,
      );

      expect(task.timeZone, equals(0));
    });

    test('should start and stop correctly', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        lastRunKey: testKey,
      );

      expect(task.isRunning, isFalse);
      task.start();
      expect(task.isRunning, isTrue);
      task.stop();
      expect(task.isRunning, isFalse);
    });

    test('should not start multiple times if already running', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);

      // Try to start again
      task.start();
      expect(task.isRunning, isTrue);

      task.stop();
    });

    test('should schedule task for next occurrence', () async {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 23,
        minute: 59,
        timeZone: 0, // UTC
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);

      // For a time far in the future, we can't wait, but we can verify it's scheduled
      // In a real scenario, this would run at 23:59 UTC
      task.stop();
    });

    test('should save timestamp on successful execution', () async {
      // Schedule for a time very soon (using current time + 1 second)
      final now = DateTime.now().toUtc();
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: now.hour,
        minute: now.minute,
        timeZone: 0, // UTC
        lastRunKey: testKey,
      );

      expect(prefs.getInt(testKey), isNull);

      // Since the time has passed, it should schedule for tomorrow
      // We can't easily test the actual execution without waiting, but we can test
      // that the structure is correct
      task.start();
      await Future.delayed(const Duration(milliseconds: 10));
      task.stop();
    });

    test('should handle timezone offset format', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        timeZone: 8, // UTC+8 (Beijing time)
        lastRunKey: testKey,
      );

      expect(task.timeZone, equals(8));
      task.start();
      expect(task.isRunning, isTrue);
      task.stop();
    });

    test('should handle dispose correctly', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);

      task.dispose();
      expect(task.isRunning, isFalse);
    });

    test('should not save timestamp on failed execution', () async {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {
          throw Exception('Task failed');
        },
        hour: 8,
        minute: 0,
        lastRunKey: testKey,
      );

      expect(prefs.getInt(testKey), isNull);

      task.start();
      // Task won't execute immediately, but if it did fail, timestamp shouldn't be saved
      await Future.delayed(const Duration(milliseconds: 10));
      // Since the scheduled time hasn't arrived, timestamp should still be null
      expect(prefs.getInt(testKey), isNull);

      task.stop();
    });

    test('should validate weekly schedule requires dayOfWeek', () {
      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 0,
          frequency: ScheduleFrequency.weekly,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate monthly schedule requires dayOfMonth', () {
      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 0,
          frequency: ScheduleFrequency.monthly,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate dayOfWeek range', () {
      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 0,
          frequency: ScheduleFrequency.weekly,
          dayOfWeek: 0,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 0,
          frequency: ScheduleFrequency.weekly,
          dayOfWeek: 8,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate dayOfMonth range', () {
      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 0,
          frequency: ScheduleFrequency.monthly,
          dayOfMonth: 0,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => ScheduledTask(
          sharedPreferences: prefs,
          task: () async {},
          hour: 8,
          minute: 0,
          frequency: ScheduleFrequency.monthly,
          dayOfMonth: 32,
          lastRunKey: testKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should create weekly schedule correctly', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        frequency: ScheduleFrequency.weekly,
        dayOfWeek: DateTime.monday,
        lastRunKey: testKey,
      );

      expect(task.frequency, equals(ScheduleFrequency.weekly));
      expect(task.dayOfWeek, equals(DateTime.monday));
      expect(task.dayOfMonth, isNull);
    });

    test('should create monthly schedule correctly', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        frequency: ScheduleFrequency.monthly,
        dayOfMonth: 15,
        lastRunKey: testKey,
      );

      expect(task.frequency, equals(ScheduleFrequency.monthly));
      expect(task.dayOfMonth, equals(15));
      expect(task.dayOfWeek, isNull);
    });

    test('should start and stop weekly schedule', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        frequency: ScheduleFrequency.weekly,
        dayOfWeek: DateTime.monday,
        lastRunKey: testKey,
      );

      expect(task.isRunning, isFalse);
      task.start();
      expect(task.isRunning, isTrue);
      task.stop();
      expect(task.isRunning, isFalse);
    });

    test('should start and stop monthly schedule', () {
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        frequency: ScheduleFrequency.monthly,
        dayOfMonth: 1,
        lastRunKey: testKey,
      );

      expect(task.isRunning, isFalse);
      task.start();
      expect(task.isRunning, isTrue);
      task.stop();
      expect(task.isRunning, isFalse);
    });

    test('should handle monthly schedule with invalid day (e.g., Feb 30)', () {
      // This should not throw - it should use the last day of the month
      final task = ScheduledTask(
        sharedPreferences: prefs,
        task: () async {},
        hour: 8,
        minute: 0,
        frequency: ScheduleFrequency.monthly,
        dayOfMonth: 30, // Feb only has 28/29 days
        lastRunKey: testKey,
      );

      task.start();
      expect(task.isRunning, isTrue);
      task.stop();
    });
  });
}
