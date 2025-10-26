// server.js
import express from "express";
import bodyParser from "body-parser";
import admin from "firebase-admin";
import cors from "cors";
import fs from "fs";

// --- Load Firebase service account ---
let serviceAccount;
if (process.env.SERVICE_ACCOUNT_BASE64) {
  try {
    const buff = Buffer.from(process.env.SERVICE_ACCOUNT_BASE64, "base64");
    serviceAccount = JSON.parse(buff.toString("utf8"));
    console.log("✅ Loaded service account from env");
  } catch (err) {
    console.error("❌ Failed to parse SERVICE_ACCOUNT_BASE64:", err);
    process.exit(1);
  }
} else {
  serviceAccount = JSON.parse(fs.readFileSync("./serviceAccountKey.json", "utf8"));
  console.log("✅ Loaded local serviceAccountKey.json");
}

// --- Initialize Firebase ---
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const app = express();
app.use(cors());
app.use(bodyParser.json());

// ✅ Register token and save to Firestore
app.post("/register-token", async (req, res) => {
  try {
    const { userId, token } = req.body;
    if (!userId || !token) {
      return res.status(400).json({ error: "userId and token are required" });
    }

    // Save token to Firestore
    await db.collection("deviceTokens").doc(userId).set(
      {
        token,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(`✅ Token registered for user ${userId}: ${token}`);
    res.json({ success: true });
  } catch (err) {
    console.error("❌ Error saving token:", err);
    res.status(500).json({ error: err.message });
  }
});

// ✅ Admin broadcast route: send message to all users
app.post("/admin/send", async (req, res) => {
  try {
    const { title, message } = req.body;
    if (!title || !message) {
      return res.status(400).json({ error: "title and message are required" });
    }

    // Get all registered tokens from Firestore
    const tokensSnapshot = await db.collection("deviceTokens").get();
    const tokens = tokensSnapshot.docs.map(doc => doc.data().token).filter(Boolean);

    if (tokens.length === 0) {
      return res.status(400).json({ error: "No tokens registered" });
    }

    console.log(`📱 Sending message to ${tokens.length} devices...`);

    // Prepare notification
    const payload = {
      notification: {
        title,
        body: message,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          sound: "default",
        },
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    };

    // Send to all tokens
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      ...payload,
    });

    console.log(`✅ Successfully sent: ${response.successCount}, failed: ${response.failureCount}`);

    // Save message to Firestore (for showing in app)
    await db.collection("adminMessages").add({
      senderName: "Admin",
      message,
      title,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({
      success: true,
      sent: response.successCount,
      failed: response.failureCount,
    });
  } catch (err) {
    console.error("❌ Error sending message:", err);
    res.status(500).json({ error: err.message });
  }
});

// ✅ List all tokens (for debugging)
app.get("/tokens", async (req, res) => {
  const snapshot = await db.collection("deviceTokens").get();
  const tokens = snapshot.docs.map(doc => ({
    userId: doc.id,
    ...doc.data(),
  }));
  res.json(tokens);
});

// Health check
app.get("/", (req, res) => res.send("✅ Backend is running on Render"));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
