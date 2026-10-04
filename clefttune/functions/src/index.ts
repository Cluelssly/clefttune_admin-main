import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

initializeApp();

const db = getFirestore();
const adminTopic = "admin_notifications";

type BadgeTier = {
  id: string;
  label: string;
  emoji: string;
  minLevel: number;
};

function toLevel(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function userName(data: FirebaseFirestore.DocumentData): string {
  return String(data.name ?? data.displayName ?? "Unknown user");
}

function userEmail(data: FirebaseFirestore.DocumentData): string {
  return String(data.email ?? "");
}

function badgeForLevel(level: number, tiers: BadgeTier[]): BadgeTier | null {
  const matchingTiers = tiers
    .filter((tier) => level >= tier.minLevel)
    .sort((a, b) => b.minLevel - a.minLevel || a.id.localeCompare(b.id));

  return matchingTiers[0] ?? null;
}

async function notifyAdmin(
  eventId: string,
  notification: {
    type: "new_user" | "badge_earned";
    userId: string;
    userName: string;
    userEmail: string;
    details: Record<string, number | string>;
    title: string;
    body: string;
  },
): Promise<void> {
  await db.collection("notifications").doc(eventId).set({
    ...notification,
    createdAt: FieldValue.serverTimestamp(),
    read: false,
    time: FieldValue.serverTimestamp(),
    isRead: false,
  });

  try {
    await getMessaging().send({
      topic: adminTopic,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: notification.type,
        userId: notification.userId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: adminTopic,
        },
      },
    });
  } catch (error) {
    logger.error("Failed to send admin push notification", {
      eventId,
      type: notification.type,
      error,
    });
    throw error;
  }
}

export const onUserCreated = onDocumentCreated("users/{userId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const name = userName(data);
  const email = userEmail(data);
  await notifyAdmin(event.id, {
    type: "new_user",
    userId: event.params.userId,
    userName: name,
    userEmail: email,
    details: {},
    title: "New user registered",
    body: `${name} (${email || "—"}) just created an account.`,
  });
});

export const onUserUpdated = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const previousLevel = toLevel(before.level ?? before.userLevel);
  const level = toLevel(after.level ?? after.userLevel);
  if (level <= previousLevel) return;

  const badgeSnapshot = await db.collection("badges").get();
  const tiers = badgeSnapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      label: String(data.badge_name ?? "Unnamed Badge"),
      emoji: String(data.emoji ?? "🏅"),
      minLevel: toLevel(data.min_level),
    };
  });
  const previousTier = badgeForLevel(previousLevel, tiers);
  const newTier = badgeForLevel(level, tiers);

  if (
    !newTier ||
    newTier.id === previousTier?.id ||
    newTier.minLevel <= (previousTier?.minLevel ?? -1)
  ) {
    return;
  }

  await notifyAdmin(event.id, {
    type: "badge_earned",
    userId: event.params.userId,
    userName: userName(after),
    userEmail: userEmail(after),
    details: {
      level,
      previousLevel,
      badgeLabel: newTier.label,
      badgeEmoji: newTier.emoji,
    },
    title: "Badge tier earned",
    body: `${userName(after)} just earned the ${newTier.emoji} ${newTier.label} badge at Level ${level}.`,
  });
});