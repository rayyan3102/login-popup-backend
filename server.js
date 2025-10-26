// server.js
import express from "express";
import bodyParser from "body-parser";
import admin from "firebase-admin";
import cors from "cors";
import fs from "fs";

// Load service account from ENV (base64) or local file if present
let serviceAccount;
if (process.env.SERVICE_ACCOUNT_BASE64) {
  try {
    const buff = Buffer.from(process.env.SERVICE_ACCOUNT_BASE64, 'base64');
    serviceAccount = JSON.parse(buff.toString('utf8'));
    console.log("✅ Loaded service account from env");
  } catch (err) {
    console.error("❌ Failed to parse SERVICE_ACCOUNT_BASE64:", err);
    process.exit(1);
  }
} else {
  // fallback for local dev (only if you have the file locally)
  serviceAccount = JSON.parse(fs.readFileSync("./serviceAccountKey.json", "utf8"));
  console.log("✅ Loaded local serviceAccountKey.json");
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore(); // only if you use Firestore
const app = express();
app.use(cors());
app.use(bodyParser.json());

let tokens = [];

// register token & send notification
app.post("/register-token", async (req, res) => {
  const { userId, token } = req.body;
  if (!token) return res.status(400).json({ error: "token required" });

  if (!tokens.includes(token)) tokens.push(token);
  console.log("✅ token registered:", token);

  const message = {
    notification: {
      title: "Login Successful 🎉",
      body: "You have successfully logged in (server).",
    },
    data: { click_action: "FLUTTER_NOTIFICATION_CLICK" },
    android: {
      priority: "high",
      notification: { channelId: "high_importance_channel", sound: "default" },
    },
    apns: { payload: { aps: { sound: "default", contentAvailable: true } } },
    token,
  };

  try {
    const resp = await admin.messaging().send(message);
    console.log("📨 Sent message:", resp);
    return res.json({ success: true, id: resp });
  } catch (err) {
    console.error("❌ FCM send error:", err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

app.get("/tokens", (req, res) => res.json({ tokens }));

app.get("/", (req, res) => {
  res.send("✅ Backend is running on Render");
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
