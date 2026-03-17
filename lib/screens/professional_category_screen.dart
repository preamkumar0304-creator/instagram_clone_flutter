import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class ProfessionalCategoryScreen extends StatefulWidget {
  final String uid;

  const ProfessionalCategoryScreen({super.key, required this.uid});

  @override
  State<ProfessionalCategoryScreen> createState() =>
      _ProfessionalCategoryScreenState();
}

class _ProfessionalCategoryScreenState
    extends State<ProfessionalCategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  String? _selected;
  bool _isSaving = false;

  final List<String> _categories = const [
    "Artist",
    "Musician/Band",
    "Blogger",
    "Clothing (Brand)",
    "Community",
    "Digital creator",
    "Education",
    "Entrepreneur",
    "Fashion",
    "Food & Beverage",
    "Gamer",
    "Health/Beauty",
    "Photographer",
    "Shopping & Retail",
    "Sports",
    "Writer",
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_selected == null || _selected!.isEmpty) return;
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .update({
            "accountType": "professional",
            "isPublic": true,
            "professionalCategory": _selected,
            "professionalType": "business",
            "accountUpdatedAt": DateTime.now(),
          });
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: "Switched to professional account.",
        clr: successColor,
      );
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      showSnackBar(context: context, content: err.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        _query.isEmpty
            ? _categories
            : _categories
                .where((c) => c.toLowerCase().contains(_query))
                .toList();
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "What best describes you?",
          style: TextStyle(color: primaryColor),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Categories help people find accounts like yours. "
              "You can change this at any time.",
              style: const TextStyle(color: secondaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search categories",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: mobileSearchColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = filtered[index];
                return RadioListTile<String>(
                  value: category,
                  groupValue: _selected,
                  activeColor: blueColor,
                  title: Text(
                    category,
                    style: const TextStyle(color: primaryColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selected = value;
                    });
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selected == null || _selected!.isEmpty
                            ? secondaryColor
                            : const Color(0xFF4666FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      _selected == null || _isSaving ? null : _saveCategory,
                  child:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            "Switch to professional account",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
