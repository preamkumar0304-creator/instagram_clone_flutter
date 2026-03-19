import 'package:flutter/cupertino.dart';
import 'package:instagram_clone_flutter_firebase/screens/activity_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/feed_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/messages_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/reels_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/search_screen.dart';

const webScreenSize = 600;
final ValueNotifier<int> storyRefreshNotifier = ValueNotifier<int>(0);

List<Widget> homeScreenItems(String uid) => [
  FeedScreen(),
  const ReelsScreen(),
  const MessagesScreen(),
  SearchScreen(),
  ProfileScreen(uid: uid),
];
