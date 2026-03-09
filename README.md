# Instagram Clone App 📸

A minimal yet powerful **Instagram-like** Flutter application built with **Flutter**, **Firebase Auth**, **Cloud Firestore**, **Firebase Storage**, and a touch of **Provider** for state management.  
The app offers essential social media features like user authentication, posting images, liking posts, leaving comments, following/unfollowing users, searching profiles, and a responsive UI that works across devices.

---

## Features 🚀

- **Authentication** 🔑
  - Sign up & login with email/password.
  - Secure authentication via Firebase Auth.

- **Posts** ➕  
  - Add new posts with captions and images.
  - Delete posts you own.
  - View posts in a clean, responsive feed layout.
  - Like/unlike posts in real time.  
  - Add comments to posts and view comments from other users.

- **Profile Management** 👤  
  - View your profile with posts count, followers, and following.  
  - Follow/unfollow other users.  
  - See other users’ profiles and their posts.  

- **Search** 🔍  
  - Search users by username.  
  - View their profiles directly from the search results.  

- **Responsive UI** 📱💻  
  - Works seamlessly on both mobile and web.  
  - Adaptive layout for different screen sizes.  

---

## 📸 Screenshots

### **Login Screen**
> A simple and intuitive login interface where users can sign in using their registered email and password.
<img src="screenshots/Login1.jpg" width="300"/>

### **Sign Up Flow (Email & Password)**
> A complete sign-up process allowing users to create accounts with email, password, username, bio and profile picture.
<p> 
<img src="screenshots/SignUp1.jpg" width="300"/>
<img src="screenshots/SignUp2.jpg" width="300"/>
<img src="screenshots/SignUp3.jpg" width="300"/>
<img src="screenshots/SignUp4.jpg" width="300"/>
<img src="screenshots/SignUp5.jpg" width="300"/>
<img src="screenshots/SignUp6.jpg" width="300"/>
<img src="screenshots/SignUp7.jpg" width="300"/>
<img src="screenshots/SignUp8.jpg" width="300"/>
</p>

### **Add Post**
> Upload photos with captions, which will be visible in the feed.
<p> 
<img src="screenshots/AddPost1.jpg" width="300"/>
<img src="screenshots/AddPost2.jpg" width="300"/>
<img src="screenshots/AddPost3.jpg" width="300"/>
<img src="screenshots/AddPost4.jpg" width="300"/>
<img src="screenshots/AddPost5.jpg" width="300"/>
<img src="screenshots/AddPost6.jpg" width="300"/>
</p>

### **Liking Posts**
> Double-tap or press the like button to like the post.
<p>
<img src="screenshots/Like1.jpg" width="300"/>
<img src="screenshots/Like2.jpg" width="300"/>
<img src="screenshots/Like3.jpg" width="300"/>
</p>

### **Follow / Unfollow Users**
> Connect with other users by following them or remove them from your following list.
<p>
<img src="screenshots/Follow1.jpg" width="300"/>
<img src="screenshots/Follow2.jpg" width="300"/>
<img src="screenshots/Follow3.jpg" width="300"/>
<img src="screenshots/Follow4.jpg" width="300"/>
<img src="screenshots/Follow5.jpg" width="300"/>
</p>

### **Commenting on Posts**
> Engage with posts by leaving comments.
<p>
<img src="screenshots/Comment1.jpg" width="300"/>
<img src="screenshots/Comment2.jpg" width="300"/>
<img src="screenshots/Comment3.jpg" width="300"/>
<img src="screenshots/Comment4.jpg" width="300"/>
<img src="screenshots/Comment5.jpg" width="300"/>
</p>

### **Profile Screen**
> Displays your profile picture, bio, follower/following count, and your posted photos in a grid layout.
<p>
<img src="screenshots/Profile1.jpg" width="300"/>
</p>

### **Main Feed**
> A scrollable feed showing posts from all the users.
<p>
<img src="screenshots/Feed1.jpg" width="300"/>
</p>

### **Searching User Profile**
> Find other users by searching their usernames and visit their profiles instantly.
<p>
<img src="screenshots/Search1.jpg" width="300"/>
<img src="screenshots/Search2.jpg" width="300"/>
</p>

### **Firebase Auth, Firestore, Storage**
<p>
<img src="screenshots/users.png"/>
<img src="screenshots/userCollection.png"/>
<img src="screenshots/profilePics.png"/>
<img src="screenshots/posts.png"/>
<img src="screenshots/postData.png"/>
</p>
---

## Dependencies 📦

This project uses the following dependencies:

- [`firebase_core`](https://pub.dev/packages/firebase_core) – Initialize and configure Firebase in your app.
- [`firebase_auth`](https://pub.dev/packages/firebase_auth) – Firebase Authentication for email/password login.
- [`cloud_firestore`](https://pub.dev/packages/cloud_firestore) – Cloud Firestore for storing user profiles, posts, and follow data.
- [`firebase_storage`](https://pub.dev/packages/firebase_storage) – Store and retrieve post images.
- [`provider`](https://pub.dev/packages/provider) – Simple and scalable state management.
- [`flutter_staggered_grid_view`](https://pub.dev/packages/flutter_staggered_grid_view) – Display posts in a staggered grid layout.
- [`image_picker`](https://pub.dev/packages/image_picker) – Select images from the gallery or camera.
- [`intl`](https://pub.dev/packages/intl) – Date formatting for posts.
- [`uuid`](https://pub.dev/packages/uuid) – Generate unique IDs for posts.
- [`flutter_svg`](https://pub.dev/packages/flutter_svg) – Render SVG icons.

---

##  Tech Stack 🛠️

- **Flutter** – Cross-platform UI toolkit.
- **Dart** – Programming language for Flutter apps.
- **Firebase Authentication** – Secure user login and signup.
- **Cloud Firestore** – Real-time database for social interactions.
- **Firebase Storage** – Media storage for posts.
- **Provider** – Simple state management.
- **VS Code / Android Studio** – Development environments.
- **Git** – Version control.

---

## Setup Instructions ⚙️

### Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com) and create a project.
2. Enable **Email/Password** under **Authentication → Sign-in method**.
3. Enable **Cloud Firestore** in Build > Firestore Database.
3. Enable **Storage** in Build > Storage.
4. Add your Android/iOS app and download `google-services.json` or `GoogleService-Info.plist`.
5. Place the config file in your app's respective folder.

### Clone and Run
   ```bash
   git clone https://github.com/yourusername/instagram_clone_flutter.git
   cd instagram-clone-flutter
   flutter pub get
   flutter run
```

## License 📄
This project is licensed under the [MIT License](LICENSE).