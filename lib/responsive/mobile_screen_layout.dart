import 'package:firebase_auth/firebase_auth.dart';
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
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
          child: SizedBox(
            height: kBottomNavigationBarHeight + 6,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: mobileBackgroundColor,
              selectedItemColor: primaryColor,
              unselectedItemColor: secondaryColor,
              iconSize: 26,
              selectedFontSize: 0,
              unselectedFontSize: 0,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: "",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_outlined),
                  activeIcon: Icon(Icons.search),
                  label: "",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.play_circle_outline),
                  activeIcon: Icon(Icons.play_circle),
                  label: "",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: "",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: "",
                ),
              ],
              currentIndex: _currentIndex,
              onTap: _onNavTap,
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
