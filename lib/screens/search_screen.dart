import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: SizedBox(height: 40,
          child: TextFormField(
            style: TextStyle(color: primaryColor),
            controller: searchController,
            decoration: InputDecoration(
              suffixIcon: GestureDetector(
                onTap: () => searchController.clear(),
                child: Icon(Icons.close, color: secondaryColor),
              ),
              contentPadding: EdgeInsets.symmetric(),
              filled: true,
              fillColor: mobileBackgroundColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: secondaryColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
              hintText: "Search for a user",
              hintStyle: TextStyle(color: secondaryColor),
              prefixIcon: Icon(Icons.search, color: secondaryColor),
            ),
            onFieldSubmitted: (value) {
              setState(() {
                isShowUsers = true;
              });
            },
          ),
        ),
      ),
      body:
          isShowUsers
              ? FutureBuilder(
                future:
                    FirebaseFirestore.instance
                        .collection("users")
                        .where(
                          "username",
                          isGreaterThanOrEqualTo: searchController.text.trim(),
                        )
                        .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  } else {
                    return ListView.builder(
                      itemCount: (snapshot.data! as dynamic).docs.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProfileScreen(
                                        uid:
                                            (snapshot.data! as dynamic)
                                                .docs[index]["uid"],
                                      ),
                                ),
                              ),
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: secondaryColor,
                                  width: 1,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  (snapshot.data! as dynamic)
                                      .docs[index]["photoUrl"],
                                ),
                              ),
                            ),
                            title: Text(
                              (snapshot.data! as dynamic)
                                  .docs[index]["username"],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              )
              : FutureBuilder(
                future: FirebaseFirestore.instance.collection("posts").get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return MasonryGridView.builder(
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    gridDelegate:
                        SliverSimpleGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder:
                        (context, index) => Image.network(
                          (snapshot.data! as dynamic).docs[index]["postUrl"],
                        ),
                  );
                },
              ),
    );
  }
}
