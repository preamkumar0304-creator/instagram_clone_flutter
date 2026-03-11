import 'package:flutter/cupertino.dart';
import 'package:instagram_clone_flutter_firebase/screens/activity_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/add_post_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/feed_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/search_screen.dart';

const webScreenSize = 600;

List<Widget> homeScreenItems(String uid) => [
  FeedScreen(),
  SearchScreen(),
  AddPostScreen(),
  ActivityScreen(),
  ProfileScreen(uid: uid),
];
