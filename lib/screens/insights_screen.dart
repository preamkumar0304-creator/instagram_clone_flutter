import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  Future<Map<String, int>> _loadInsights(String uid) async {
    final snap =
        await FirebaseFirestore.instance
            .collection("posts")
            .where("uid", isEqualTo: uid)
            .get();
    final since = DateTime.now().subtract(const Duration(days: 30));
    int impressions = 0;
    int reach = 0;
    int profileVisits = 0;
    int comments = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final postedAt = data["postedDate"];
      DateTime? postedDate;
      if (postedAt is Timestamp) {
        postedDate = postedAt.toDate();
      } else if (postedAt is DateTime) {
        postedDate = postedAt;
      }
      if (postedDate == null || postedDate.isBefore(since)) {
        continue;
      }
      impressions += _safeInt(data["impressions"]);
      reach += _safeInt(data["reach"]);
      profileVisits += _safeInt(data["profileVisits"]);
      comments += _safeInt(data["commentCount"]);
    }
    return {
      "impressions": impressions,
      "reach": reach,
      "profileVisits": profileVisits,
      "comments": comments,
    };
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _formatCompact(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: mobileBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Insights", style: TextStyle(color: primaryColor)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadInsights(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }
          final data = snapshot.data ?? {};
          final impressions = data["impressions"] ?? 0;
          final reach = data["reach"] ?? 0;
          final profileVisits = data["profileVisits"] ?? 0;
          final comments = data["comments"] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Last 30 days",
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _InsightCard(
                title: "Views",
                value: _formatCompact(impressions),
              ),
              _InsightCard(
                title: "Reach",
                value: _formatCompact(reach),
              ),
              _InsightCard(
                title: "Profile visits",
                value: _formatCompact(profileVisits),
              ),
              _InsightCard(
                title: "Comments",
                value: _formatCompact(comments),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;

  const _InsightCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
