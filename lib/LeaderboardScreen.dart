import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:Boomverse/services/analytics_service.dart';
import 'package:firebase_database/firebase_database.dart';

class LeaderboardScreen extends StatefulWidget {
   const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final AnalyticsService _analytics = AnalyticsService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _analytics.logLeaderboardView();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    try {
      setState(() => _isLoading = true);
      final snapshot =
          await _database
              .ref('leaderboard')
              .orderByChild('score')
              .limitToLast(10)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _leaderboardData =
            data.entries.map((entry) {
              return {
                'name': entry.value['name'] ?? 'Anonymous',
                'score': entry.value['score'] ?? 0,
              };
            }).toList();

        _leaderboardData.sort(
          (a, b) => (b['score'] as int).compareTo(a['score'] as int),
        );
      }
    } catch (e) {
      _analytics.logError('leaderboard_load', e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading leaderboard: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: _leaderboardData.length,
                itemBuilder: (context, index) {
                  final entry = _leaderboardData[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(entry['name']),
                    trailing: Text('${entry['score']}'),
                  );
                },
              ),
    );
  }
}
