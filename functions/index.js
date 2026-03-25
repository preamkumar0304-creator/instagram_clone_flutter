const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

function buildNotificationText(data) {
  const sender = data.senderUsername || "Someone";
  switch (data.type) {
    case "like":
      return { title: "New like", body: `${sender} liked your post.` };
    case "comment":
      return {
        title: "New comment",
        body: `${sender} commented: ${data.message || "Your post"}`,
      };
    case "message":
      return { title: "New message", body: `${sender}: ${data.message || ""}` };
    case "follow":
      return { title: "New follower", body: `${sender} started following you.` };
    case "follow_request":
      return { title: "Follow request", body: `${sender} requested to follow you.` };
    case "follow_accept":
      return { title: "Follow accepted", body: `${sender} accepted your request.` };
    case "share_reel":
      return { title: "Reel shared", body: `${sender} shared a reel with you.` };
    case "share_profile":
      return { title: "Profile shared", body: `${sender} shared a profile.` };
    case "live":
      return { title: "Live now", body: `${sender} is live now.` };
    case "share_post":
      return { title: "Post shared", body: `${sender} shared a post with you.` };
    default:
      return { title: "Notification", body: `${sender} sent a notification.` };
  }
}

exports.sendNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const receiverId = data.receiverId;
    const senderId = data.senderId;
    if (!receiverId || !senderId || receiverId === senderId) {
      return null;
    }

    const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
    const userData = userSnap.data() || {};
    const tokens = userData.fcmTokens || [];
    if (!Array.isArray(tokens) || tokens.length === 0) {
      return null;
    }

    const { title, body } = buildNotificationText(data);

    const message = {
      tokens: tokens,
      notification: { title, body },
      data: {
        notificationId: String(data.notificationId || snap.id),
        senderId: String(senderId || ""),
        receiverId: String(receiverId || ""),
        type: String(data.type || ""),
        message: String(data.message || ""),
        postId: String(data.postId || ""),
        reelId: String(data.reelId || ""),
        liveId: String(data.liveId || ""),
        profileUid: String(data.profileUid || ""),
        senderUsername: String(data.senderUsername || ""),
        senderPhotoUrl: String(data.senderPhotoUrl || ""),
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    const invalidTokens = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const err = res.error;
        const code = err && err.code ? err.code : "";
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await admin.firestore().collection("users").doc(receiverId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }

    return null;
  });
