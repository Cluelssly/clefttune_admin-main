// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE — functions/index.js
//
// Firebase Cloud Functions that watch Firestore and send
// real push notifications to the admin via FCM.
//
// SETUP:
//   1. npm install -g firebase-tools
//   2. firebase login
//   3. firebase init functions  (choose JavaScript)
//   4. cd functions && npm install
//   5. Replace ADMIN_UID below with your actual Firestore admin UID
//   6. firebase deploy --only functions
// ═══════════════════════════════════════════════════════════════════

const functions = require("firebase-functions");
const admin     = require("firebase-admin");

admin.initializeApp();

const db  = admin.firestore();
const fcm = admin.messaging();

// ─────────────────────────────────────────────
// HELPER — get admin FCM token from Firestore
// ─────────────────────────────────────────────
async function getAdminToken() {
  // Replace with your actual admin Firestore UID
  // This is the UID saved by NotificationService._saveFcmToken()
  const ADMIN_UID = "YOUR_ADMIN_FIRESTORE_UID"; // 🔑 Replace this

  const doc = await db.collection("admins").doc(ADMIN_UID).get();
  if (!doc.exists) return null;
  return doc.data()?.fcmToken ?? null;
}

// ─────────────────────────────────────────────
// HELPER — send FCM message
// ─────────────────────────────────────────────
async function sendToAdmin({ title, body, type }) {
  const token = await getAdminToken();
  if (!token) {
    console.log("No admin FCM token found.");
    return;
  }

  const message = {
    token,
    notification: { title, body },
    data:         { type: type ?? "general" },
    android: {
      priority: "high",
      notification: {
        channelId: "clefttune_admin_high",
        priority:  "max",
        sound:     "default",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
          badge: 1,
        },
      },
    },
    webpush: {
      notification: {
        title,
        body,
        icon: "/icons/icon-192x192.png",
      },
    },
  };

  try {
    const response = await fcm.send(message);
    console.log(`✅ Notification sent [${type}]: ${response}`);
  } catch (err) {
    console.error(`❌ FCM error [${type}]:`, err);
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 1 — New user registered
// ═══════════════════════════════════════════════════════════════════
exports.onNewUser = functions.firestore
  .document("users/{userId}")
  .onCreate(async (snap) => {
    const data  = snap.data();
    const name  = data?.name  ?? "Someone";
    const email = data?.email ?? "—";

    await sendToAdmin({
      title: "👤 New User Registered",
      body:  `${name} (${email}) just created an account.`,
      type:  "new_user",
    });
  });

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 2 — New payment submitted (status = pending)
// ═══════════════════════════════════════════════════════════════════
exports.onNewPayment = functions.firestore
  .document("payments/{paymentId}")
  .onCreate(async (snap) => {
    const data   = snap.data();
    const status = (data?.status ?? "").toLowerCase();
    if (status !== "pending") return;

    const method = (data?.method ?? "").toUpperCase();
    const ref    = data?.referenceNumber ?? "—";
    const amount = data?.amount ?? 99;

    // Try to get user name from users collection
    let userName = "A user";
    if (data?.userId) {
      const userDoc = await db.collection("users").doc(data.userId).get();
      if (userDoc.exists) userName = userDoc.data()?.name ?? "A user";
    }

    await sendToAdmin({
      title: "💳 New Payment Submitted",
      body:  `${userName} submitted ₱${amount} via ${method}. Ref: ${ref}. Needs review!`,
      type:  "payment_pending",
    });
  });

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 3 — Payment status changed (verified / rejected)
// ═══════════════════════════════════════════════════════════════════
exports.onPaymentUpdated = functions.firestore
  .document("payments/{paymentId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    const prevStatus = (before?.status ?? "").toLowerCase();
    const newStatus  = (after?.status  ?? "").toLowerCase();

    // Only fire if status actually changed
    if (prevStatus === newStatus) return;

    const method = (after?.method ?? "").toUpperCase();
    const ref    = after?.referenceNumber ?? "—";
    const amount = after?.amount ?? 99;

    let userName = "A user";
    if (after?.userId) {
      const userDoc = await db.collection("users").doc(after.userId).get();
      if (userDoc.exists) userName = userDoc.data()?.name ?? "A user";
    }

    if (newStatus === "verified") {
      await sendToAdmin({
        title: "✅ Payment Verified",
        body:  `₱${amount} ${method} from ${userName} (Ref: ${ref}) verified. User upgraded to Premium.`,
        type:  "payment_verified",
      });
    }

    if (newStatus === "rejected") {
      const reason = after?.rejectionReason ?? "";
      await sendToAdmin({
        title: "❌ Payment Rejected",
        body:  `₱${amount} ${method} from ${userName} (Ref: ${ref}) rejected.${reason ? " Reason: " + reason : ""}`,
        type:  "payment_rejected",
      });
    }
  });

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 4 — User upgraded to Premium
// ═══════════════════════════════════════════════════════════════════
exports.onUserUpgraded = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    const wasPremium = before?.isPremium === true;
    const isPremium  = after?.isPremium  === true;

    if (!wasPremium && isPremium) {
      const name  = after?.name  ?? "A user";
      const email = after?.email ?? "—";
      await sendToAdmin({
        title: "⭐ User Upgraded to Premium",
        body:  `${name} (${email}) is now a Premium member!`,
        type:  "new_premium",
      });
    }

    // Premium cancelled
    const hadCancel = before?.cancelledAt != null;
    const hasCancel = after?.cancelledAt  != null;
    if (!hadCancel && hasCancel) {
      const name  = after?.name  ?? "A user";
      const email = after?.email ?? "—";
      await sendToAdmin({
        title: "🚫 Premium Cancelled",
        body:  `${name} (${email}) cancelled their Premium subscription.`,
        type:  "premium_cancelled",
      });
    }

    // Account updated (name/email changed)
    const nameChanged  = before?.name  !== after?.name;
    const emailChanged = before?.email !== after?.email;
    if (nameChanged || emailChanged) {
      const name    = after?.name  ?? "A user";
      const changed = [];
      if (nameChanged)  changed.push("name");
      if (emailChanged) changed.push("email");
      await sendToAdmin({
        title: "✏️ Profile Updated",
        body:  `${name} updated their ${changed.join(" & ")}.`,
        type:  "profile_updated",
      });
    }
  });

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 5 — User deleted their account
// ═══════════════════════════════════════════════════════════════════
exports.onUserDeleted = functions.firestore
  .document("users/{userId}")
  .onDelete(async (snap) => {
    const data  = snap.data();
    const name  = data?.name  ?? "A user";
    const email = data?.email ?? "—";

    await sendToAdmin({
      title: "🗑️ Account Deleted",
      body:  `${name} (${email}) permanently deleted their account.`,
      type:  "account_deleted",
    });
  });