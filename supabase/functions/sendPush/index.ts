// index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Function starts
serve(async (req) => {
  try {
    // Read environment variables
    const GOOGLE_SERVICE_ACCOUNT_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
    if (!GOOGLE_SERVICE_ACCOUNT_JSON) {
      throw new Error("Missing GOOGLE_SERVICE_ACCOUNT_JSON in environment");
    }

    // Parse incoming request payload
    const body = await req.json();
    const record = body.record || {};
    const title = record.title || "New Notification";
    const bodyText = record.body || "You have a new message!";
    // Fetch employee token from employee_records
    let fcmToken = record.fcm_token;
    if (!fcmToken && record.employee_id) {
      const { data, error } = await supabase
        .from("employee_records")
        .select("fcm_token")
        .eq("employee_id", record.employee_id)
        .single();

      if (error) throw new Error(`Employee token lookup failed: ${error.message}`);
      fcmToken = data.fcm_token;
    }// token should be stored per user in DB

    if (!fcmToken) {
      throw new Error("Missing FCM token in notification record");
    }

    // Prepare JWT from service account for Firebase Authentication
    const googleAccount = JSON.parse(GOOGLE_SERVICE_ACCOUNT_JSON);
    const now = Math.floor(Date.now() / 1000);
    const jwtHeader = { alg: "RS256", typ: "JWT" };
    const jwtPayload = {
      iss: googleAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    };

    // Helper: base64url encode
    const encode = (obj: any) =>
      btoa(JSON.stringify(obj))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/, "");

    const headerEncoded = encode(jwtHeader);
    const payloadEncoded = encode(jwtPayload);
    const data = `${headerEncoded}.${payloadEncoded}`;

    const key = await crypto.subtle.importKey(
      "pkcs8",
      new TextEncoder().encode(googleAccount.private_key),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(data),
    );

    const signatureEncoded = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

    const jwt = `${data}.${signatureEncoded}`;

    // Exchange JWT for access token
    const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    const tokenData = await tokenResp.json();
    const accessToken = tokenData.access_token;

    if (!accessToken) throw new Error("Failed to retrieve access token from Google");

    // Send notification via Firebase Cloud Messaging
    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: bodyText,
        },
      },
    };

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${googleAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      },
    );

    const fcmResult = await fcmResponse.json();

    return new Response(
      JSON.stringify({ success: true, message: "Push sent!", result: fcmResult }),
      { headers: { "Content-Type": "application/json" }, status: 200 },
    );
  } catch (error) {
    console.error("Push Notification Error:", error.message);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 500 },
    );
  }
});
