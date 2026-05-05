import { createClient } from "@supabase/supabase-js";
import admin from "firebase-admin";
import fs from "fs";

// ---------------- Firebase Service Account ----------------
const serviceAccount = JSON.parse(fs.readFileSync("./serviceAccount.json", "utf8"));

// ---------------- Supabase Config ----------------
const supabase = createClient(
  "https://erjqikaafyefaujyzrax.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyanFpa2FhZnllZmF1anl6cmF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTA2MjExNSwiZXhwIjoyMDcwNjM4MTE1fQ.4TlpFOE6SbqBY8w-o-2edYUWGMGMzSfku1-I6RsRhkc"
);

// ---------------- Firebase Config ----------------
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

console.log("🚀 Push worker starting...");


// ---------------- Realtime Listener ----------------
const channel = supabase.channel("notifications_channel");

channel
  .on(
    "postgres_changes",
    { event: "INSERT", schema: "public", table: "notifications" },
    async (payload) => {
      console.log("📩 New notification detected:", payload.new.title);

      const { recipient_employee_id, title, body } = payload.new;

      // Fetch employee FCM token
      const { data: employee, error } = await supabase
        .from("employee_records")
        .select("fcm_token")
        .eq("id", recipient_employee_id)
        .single();

      if (error || !employee?.fcm_token) {
        console.error("⚠️ No FCM token found for this employee.");
        return;
      }

      const fcmToken = employee.fcm_token;
      console.log("📤 Sending push notification to:", fcmToken);

      try {
        const message = {
          token: fcmToken,
          notification: {
            title,
            body,
          },
        };

        const response = await admin.messaging().send(message);
        console.log("✅ Successfully delivered via FCM!", response);
      } catch (err) {
        console.error("❌ FCM send failed:", err.message);
      }
    }
  )
  .subscribe(async (status) => {
    if (status === "SUBSCRIBED") {
      console.log("🛰️ Listening for new notifications via Supabase Realtime...");
    }
  });
