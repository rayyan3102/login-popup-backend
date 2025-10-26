// --- IMPORTS ---
import express from "express";
import bodyParser from "body-parser";
import admin from "firebase-admin";
import cors from "cors";
import fs from "fs";

// --- FIREBASE ADMIN SETUP ---
const serviceAccount = JSON.parse(
  fs.readFileSync("./serviceAccountKey.json", "utf8")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// --- EXPRESS SETUP ---
const app = express();
app.use(cors());
app.use(bodyParser.json());

// Temporary in-memory storage (can be replaced with SQL or Firestore)
let tokens = [];

// ✅ Register device token and send push notification
app.post("/register-token", async (req, res) => {
  const { token } = req.body;

  if (!token) {
    return res.status(400).send("Token is required");
  }

  // Save token if new
  if (!tokens.includes(token)) {
    tokens.push(token);
    console.log("✅ New token registered:", token);
  }

  // ✅ Create a properly structured FCM message
  const message = {
    notification: {
      title: "Login Successful 🎉",
      body: "You have successfully logged in from the server!",
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK", // helps Flutter handle taps
      screen: "login", // optional custom data
    },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        sound: "default",
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
        },
      },
    },
    token,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("📨 Push notification sent:", response);
    res.status(200).send("✅ Notification sent successfully");
  } catch (error) {
    console.error("❌ Error sending notification:", error);
    res.status(500).send("Failed to send notification");
  }
});

// --- OPTIONAL: List all tokens ---
app.get("/tokens", (req, res) => {
  res.json(tokens);
});

// --- START SERVER ---
const PORT = 3000;
app.listen(PORT, () =>
  console.log(`🚀 Server running on http://localhost:${PORT}`)
);
