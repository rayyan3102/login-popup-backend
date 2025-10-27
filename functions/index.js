const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * This function triggers when a new document is created
 * in the 'adminMessages' collection.
 */
exports.sendAdminPushNotification = functions.firestore
  .document("adminMessages/{messageId}")
  .onCreate(async (snapshot, context) => {

    // Get the data from the new message document
    const messageData = snapshot.data();

    // Create the notification payload
    const payload = {
      notification: {
        // e.g., "Admin"
        title: messageData.senderName || "New Message", 
        // e.g., "Hello everyone!"
        body: messageData.message || "You have a new message.",
      },
      // This is the "channel" name all your apps will listen to
      topic: "admin_messages_topic", 
    };

    // Send the notification to all devices subscribed to the topic
    try {
      console.log("Sending notification:", payload);
      await admin.messaging().send(payload);
      console.log("Successfully sent notification");
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  });