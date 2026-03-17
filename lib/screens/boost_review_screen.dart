import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class BoostReviewScreen extends StatefulWidget {
  final String postId;
  final String postUrl;
  final int days;
  final int interval;
  final int maxInsertions;

  const BoostReviewScreen({
    super.key,
    required this.postId,
    required this.postUrl,
    required this.days,
    required this.interval,
    required this.maxInsertions,
  });

  @override
  State<BoostReviewScreen> createState() => _BoostReviewScreenState();
}

class _BoostReviewScreenState extends State<BoostReviewScreen> {
  String _goal = "More messages";
  String _audience = "Near you";
  int _dailyBudget = 174;
  int _durationDays = 1;
  bool _financialAd = false;

  Future<void> _editGoal() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _BoostGoalScreen(initial: _goal),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _goal = selected;
      });
    }
  }

  Future<void> _editAudience() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _BoostAudienceScreen(initial: _audience),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _audience = selected;
      });
    }
  }

  Future<void> _editBudget() async {
    final selected = await Navigator.of(context).push<_BudgetResult>(
      MaterialPageRoute(
        builder:
            (_) => _BoostBudgetScreen(
              dailyBudget: _dailyBudget,
              durationDays: _durationDays,
            ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _dailyBudget = selected.dailyBudget;
        _durationDays = selected.durationDays;
      });
    }
  }

  Future<void> _applyBoost() async {
    if (widget.postId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.postId)
        .update({
          "isBoosted": true,
          "boostInterval": widget.interval,
          "boostMaxInsertions": widget.maxInsertions,
          "boostedAt": DateTime.now(),
          "boostExpiresAt":
              DateTime.now().add(Duration(days: widget.days)),
          "boostGoal": _goal,
          "boostAudience": _audience,
          "boostDailyBudget": _dailyBudget,
          "boostDurationDays": _durationDays,
          "boostFinancial": _financialAd,
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Ad was successfully boosted."),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Review", style: TextStyle(color: primaryColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTile(
            title: "Goal",
            subtitle:
                "More messages to\nOutcome: Conversations\nAction Button: Chat on WhatsApp",
            onTap: _editGoal,
          ),
          const SizedBox(height: 4),
          _SectionTile(
            title: "Audience",
            subtitle:
                "$_audience | Advantage+ audience | Ages 18+\nSuggestions: Men and women, 18 - 40",
            onTap: _editAudience,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "This ad is about financial products",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Includes ads about securities and investments",
                        style: TextStyle(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _financialAd,
                  activeColor: blueColor,
                  onChanged: (value) {
                    setState(() {
                      _financialAd = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            title: "Budget and duration",
            subtitle: "\u20b9$_dailyBudget over $_durationDays day",
            onTap: _editBudget,
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text(
              "Preview ad",
              style: TextStyle(color: primaryColor),
            ),
            trailing: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.postUrl.isNotEmpty
                  ? Image.network(
                    widget.postUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 56,
                    height: 56,
                    color: Colors.black12,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: secondaryColor,
                    ),
                  ),
            ),
          ),
          const Divider(color: Colors.black12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text(
              "Payment method",
              style: TextStyle(color: primaryColor),
            ),
            subtitle: const Text(
              "Funds available: \u20b9 4.74",
              style: TextStyle(color: secondaryColor),
            ),
            trailing: TextButton(
              onPressed: () {},
              child: const Text("Add Funds"),
            ),
          ),
          const Divider(color: Colors.black12),
          const Text(
            "Payment summary",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: "Ad budget", value: "\u20b9 174"),
          _SummaryRow(label: "Estimated GST", value: "\u20b9 31.32"),
          const Divider(color: Colors.black12),
          _SummaryRow(
            label: "Total",
            value: "\u20b9 205.32",
            bold: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyBoost,
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Boost post",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: primaryColor,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: primaryColor)),
      subtitle: Text(subtitle, style: const TextStyle(color: secondaryColor)),
      trailing: const Icon(Icons.chevron_right, color: secondaryColor),
      onTap: onTap,
    );
  }
}

class _BoostGoalScreen extends StatefulWidget {
  final String initial;
  const _BoostGoalScreen({required this.initial});

  @override
  State<_BoostGoalScreen> createState() => _BoostGoalScreenState();
}

class _BoostGoalScreenState extends State<_BoostGoalScreen> {
  final List<String> _options = [
    "Visit your profile",
    "Visit your website",
    "Message you",
    "A mix of actions",
  ];
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Goal", style: TextStyle(color: primaryColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: primaryColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "What do you want people to do when they see your ad?",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              children: _options.map((option) {
                return RadioListTile<String>(
                  value: option,
                  groupValue: _selected,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selected = value;
                    });
                  },
                  title: Text(option, style: const TextStyle(color: primaryColor)),
                  activeColor: blueColor,
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostAudienceScreen extends StatefulWidget {
  final String initial;
  const _BoostAudienceScreen({required this.initial});

  @override
  State<_BoostAudienceScreen> createState() => _BoostAudienceScreenState();
}

class _BoostAudienceScreenState extends State<_BoostAudienceScreen> {
  final List<String> _options = [
    "Suggested audience",
    "Near you",
    "Create your own",
  ];
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Audience", style: TextStyle(color: primaryColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: primaryColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Special requirements",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: _options.map((option) {
                return RadioListTile<String>(
                  value: option,
                  groupValue: _selected,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selected = value;
                    });
                  },
                  title: Text(option, style: const TextStyle(color: primaryColor)),
                  activeColor: blueColor,
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetResult {
  final int dailyBudget;
  final int durationDays;

  const _BudgetResult({
    required this.dailyBudget,
    required this.durationDays,
  });
}

class _BoostBudgetScreen extends StatefulWidget {
  final int dailyBudget;
  final int durationDays;

  const _BoostBudgetScreen({
    required this.dailyBudget,
    required this.durationDays,
  });

  @override
  State<_BoostBudgetScreen> createState() => _BoostBudgetScreenState();
}

class _BoostBudgetScreenState extends State<_BoostBudgetScreen> {
  late double _budget;
  late double _days;

  @override
  void initState() {
    super.initState();
    _budget = widget.dailyBudget.toDouble();
    _days = widget.durationDays.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "Budget and duration",
          style: TextStyle(color: primaryColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: primaryColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.center,
              child: Text(
                "What's your ad budget?",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Daily budget",
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _budget,
              min: 100,
              max: 500,
              divisions: 8,
              label: _budget.toStringAsFixed(0),
              onChanged: (value) {
                setState(() {
                  _budget = value;
                });
              },
            ),
            Text(
              "\u20b9${_budget.toStringAsFixed(0)} daily",
              style: const TextStyle(color: secondaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              "Duration",
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _days,
              min: 1,
              max: 14,
              divisions: 13,
              label: _days.toStringAsFixed(0),
              onChanged: (value) {
                setState(() {
                  _days = value;
                });
              },
            ),
            Text(
              "${_days.toStringAsFixed(0)} day",
              style: const TextStyle(color: secondaryColor),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _BudgetResult(
                      dailyBudget: _budget.toInt(),
                      durationDays: _days.toInt(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
