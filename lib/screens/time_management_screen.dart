import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/app_usage_tracker.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:provider/provider.dart';

class TimeManagementScreen extends StatefulWidget {
  const TimeManagementScreen({super.key});

  @override
  State<TimeManagementScreen> createState() => _TimeManagementScreenState();
}

class _TimeManagementScreenState extends State<TimeManagementScreen> {
  String _formatUsage(int seconds) {
    if (seconds <= 0) return "0m";
    final minutes = seconds ~/ 60;
    if (minutes < 60) return "${minutes}m";
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return remMinutes == 0 ? "${hours}h" : "${hours}h ${remMinutes}m";
  }

  String _formatLimit(int minutes) {
    if (minutes <= 0) return "No limit";
    if (minutes < 60) return "${minutes}m";
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? "${hours}h" : "${hours}h ${rem}m";
  }

  String _formatTime(BuildContext context, int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }

  Future<void> _editDailyLimit({
    required String uid,
    required int currentMinutes,
  }) async {
    final controller = TextEditingController(
      text: currentMinutes > 0 ? currentMinutes.toString() : "",
    );
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: const Text(
            "Daily limit (minutes)",
            style: TextStyle(color: primaryColor),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter minutes (0 = no limit)",
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final minutes = int.tryParse(value.trim());
                if (minutes == null || minutes < 0) {
                  return "Enter a valid number.";
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final raw = controller.text.trim();
    final minutes = raw.isEmpty ? 0 : int.tryParse(raw) ?? 0;
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "dailyLimitMinutes": minutes,
    });
  }

  Future<void> _updateSleepMinutes(
    String uid,
    String field,
    int value,
  ) async {
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      field: value,
    });
  }

  Future<void> _pickSleepTime({
    required String uid,
    required int currentMinutes,
    required String field,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await _updateSleepMinutes(uid, field, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: mobileBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final usage = context.watch<AppUsageTracker>();
    final usageSeconds = usage.todayUsageSeconds;
    final usageMinutes = usageSeconds ~/ 60;

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Time management", style: TextStyle(color: primaryColor)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final dailyLimit = (data["dailyLimitMinutes"] as int?) ?? 0;
          final sleepEnabled = data["sleepModeEnabled"] == true;
          final sleepStart = (data["sleepStartMinutes"] as int?) ?? 1320;
          final sleepEnd = (data["sleepEndMinutes"] as int?) ?? 420;

          final limitReached =
              dailyLimit > 0 && usageMinutes >= dailyLimit;
          final progress =
              dailyLimit > 0 ? (usageMinutes / dailyLimit).clamp(0.0, 1.0) : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: secondaryColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Time used today",
                      style: TextStyle(
                        color: secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatUsage(usageSeconds),
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dailyLimit > 0) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: secondaryColor.withOpacity(0.2),
                        color: limitReached ? Colors.red : primaryColor,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${_formatUsage(usageSeconds)} of ${_formatLimit(dailyLimit)}",
                        style: TextStyle(
                          color: limitReached ? Colors.red : secondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.timelapse, color: primaryColor),
                title: const Text("Daily limit"),
                subtitle: Text(
                  _formatLimit(dailyLimit),
                  style: const TextStyle(color: secondaryColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () => _editDailyLimit(
                  uid: uid,
                  currentMinutes: dailyLimit,
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.bedtime_outlined, color: primaryColor),
                title: const Text("Sleep mode"),
                subtitle: Text(
                  sleepEnabled ? "On" : "Off",
                  style: const TextStyle(color: secondaryColor),
                ),
                value: sleepEnabled,
                activeColor: primaryColor,
                onChanged: (value) async {
                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(uid)
                      .update({"sleepModeEnabled": value});
                },
              ),
              if (sleepEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.nights_stay, color: primaryColor),
                  title: const Text("Sleep start"),
                  subtitle: Text(
                    _formatTime(context, sleepStart),
                    style: const TextStyle(color: secondaryColor),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: secondaryColor),
                  onTap: () => _pickSleepTime(
                    uid: uid,
                    currentMinutes: sleepStart,
                    field: "sleepStartMinutes",
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined, color: primaryColor),
                  title: const Text("Sleep end"),
                  subtitle: Text(
                    _formatTime(context, sleepEnd),
                    style: const TextStyle(color: secondaryColor),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: secondaryColor),
                  onTap: () => _pickSleepTime(
                    uid: uid,
                    currentMinutes: sleepEnd,
                    field: "sleepEndMinutes",
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
