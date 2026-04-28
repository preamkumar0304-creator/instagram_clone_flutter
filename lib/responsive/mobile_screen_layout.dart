import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/audio_manager.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({super.key});

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  int _currentIndex = 0;
  late final PageController _pageController;
  List<Widget>? _pages;
  String? _pagesUid;
  static const double _fastSwipeVelocity = 1800;

  void _onNavTap(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int page) {
    AudioManager.instance.pauseAudio();
    homeTabIndexNotifier.value = page;
    setState(() {
      _currentIndex = page;
    });
  }

  bool _handleFastSwipe(ScrollEndNotification notification) {
    final details = notification.dragDetails;
    if (details == null || _pages == null) return false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _fastSwipeVelocity) return false;
    final maxIndex = _pages!.length - 1;
    final target = velocity < 0 ? _currentIndex + 1 : _currentIndex - 1;
    if (target < 0 || target > maxIndex) return false;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    return false;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    homeTabIndexNotifier.value = _currentIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pages == null || _pagesUid != currentUser.uid) {
      _pages = homeScreenItems(currentUser.uid);
      _pagesUid = currentUser.uid;
    }

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          _onNavTap(0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              color: mobileBackgroundColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: kBottomNavigationBarHeight + 6,
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: mobileBackgroundColor,
                  elevation: 0,
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.black54,
                  iconSize: 25,
                  selectedFontSize: 0,
                  unselectedFontSize: 0,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.house),
                      activeIcon: Icon(CupertinoIcons.house_fill),
                      label: "",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.compass),
                      activeIcon: Icon(CupertinoIcons.compass_fill),
                      label: "",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.play_rectangle),
                      activeIcon: Icon(CupertinoIcons.play_rectangle_fill),
                      label: "",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.chat_bubble),
                      activeIcon: Icon(CupertinoIcons.chat_bubble_fill),
                      label: "",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.person_crop_circle),
                      activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
                      label: "",
                    ),
                  ],
                  currentIndex: _currentIndex,
                  onTap: _onNavTap,
                ),
              ),
            ),
          ),
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (overscroll) {
            overscroll.disallowIndicator();
            return false;
          },
          child: NotificationListener<ScrollEndNotification>(
            onNotification: _handleFastSwipe,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              children: _pages!,
            ),
          ),
        ),
      ),
    );
  }
}
