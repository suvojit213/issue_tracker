import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  static const platform = MethodChannel('com.suvojeet.issue_tracker_app/notifications');
  List<String> _notificationHistory = [];

  @override
  void initState() {
    super.initState();
    _getNotificationHistory();
  }

  Future<void> _getNotificationHistory() async {
    List<String> history = [];
    try {
      final List<dynamic>? result = await platform.invokeMethod('getNotificationHistory');
      if (result != null) {
        history = result.cast<String>();
      }
    } on PlatformException catch (e) {
      print("Failed to get notification history: '${e.message}'.");
    }

    setState(() {
      _notificationHistory = history.reversed.toList(); // Show newest first
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
      ),
      body: _notificationHistory.isEmpty
          ? const Center(child: Text('No notifications yet.'))
          : ListView.builder(
              itemCount: _notificationHistory.length,
              itemBuilder: (context, index) {
                final notification = _notificationHistory[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(notification),
                  ),
                );
              },
            ),
    );
  }
}
