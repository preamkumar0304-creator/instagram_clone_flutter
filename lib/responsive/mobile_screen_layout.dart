import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({super.key});

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  int _page = 0;
  late PageController pageController;

  void navigationTapped(int page) {
    pageController.jumpToPage(page);
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = homeScreenItems(currentUser.uid);

    return WillPopScope(
      onWillPop: () async {
        if (_page != 0) {
          navigationTapped(0);
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
              unselectedItemColor: Colors.grey,
              iconSize: 28,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.play_circle_outline),
                  label: "Reels",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.forum_outlined),
                  label: "Messages",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.travel_explore),
                  label: "Search",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle_outlined),
                  label: "Profile",
                ),
              ],
              currentIndex: _page,
              onTap: navigationTapped,
            ),
          ),
        ),
        body: PageView(
          controller: pageController,
          onPageChanged: onPageChanged,
          physics: NeverScrollableScrollPhysics(),
          children: items,
        ),
      ),
    );
  }
}
