import 'dart:math';

class NotificationContent {
  static final _random = Random();

  static const List<Map<String, String>> dailyReminders = [
    {
      'title': 'Did you buy a coffee today? ☕',
      'body': 'Take 30 seconds to log today\'s expenses and stay on track.',
    },
    {
      'title': 'Don\'t let your money run away! 🏃‍♂️',
      'body': 'Track what you spent today so you can save more tomorrow.',
    },
    {
      'title': 'How was your spending today? 📊',
      'body': 'Review your daily budget and add any missing transactions.',
    },
    {
      'title': 'Keep your streak alive! 🔥',
      'body': 'Log today\'s expenses to maintain your good financial habits!',
    },
  ];

  static const List<Map<String, String>> weeklySummaries = [
    {
      'title': 'Your Weekly Insights are Ready! 📈',
      'body': 'Tap to see how you managed your money this week.',
    },
    {
      'title': 'Sunday Finance Review 💡',
      'body': 'Did you stay under budget? Tap to view your weekly summary.',
    },
    {
      'title': 'Weekly Spend Check 📅',
      'body':
          'Let\'s review what you spent this week to plan for the next one.',
    },
  ];

  static const List<Map<String, String>> inactivityNudges = [
    {
      'title': 'It\'s quiet... too quiet 👀',
      'body': 'We haven\'t seen any transactions lately. Did you spend cash?',
    },
    {
      'title': 'Did you make a sneaky purchase? 🕵️‍♂️',
      'body':
          'You haven\'t logged anything in 3 days. Keep your accounts accurate!',
    },
    {
      'title': 'Missing something? 🧐',
      'body': 'Unrecorded cash expenses can ruin your budget. Add them now.',
    },
  ];

  static Map<String, String> getDailyReminder() {
    return dailyReminders[_random.nextInt(dailyReminders.length)];
  }

  static Map<String, String> getWeeklySummary() {
    return weeklySummaries[_random.nextInt(weeklySummaries.length)];
  }

  static Map<String, String> getInactivityNudge() {
    return inactivityNudges[_random.nextInt(inactivityNudges.length)];
  }
}
