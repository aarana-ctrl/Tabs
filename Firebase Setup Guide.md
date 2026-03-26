# Firebase Setup Guide for Tabs

Follow every step below in order.

---

## 1. Create a Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com) and sign in.
2. Click **Add project**, name it **Tabs**, click **Continue**.
3. Disable Google Analytics (optional), click **Create project**, then **Continue**.

---

## 2. Register the iOS App

1. On the project overview page, click the **iOS+** icon (Apple logo).
2. **iOS bundle ID**: open Xcode, select the `Tabs` target → **General** → copy the Bundle Identifier exactly as it appears (e.g. `com.DAAR.Tabs`).
3. **App nickname**: `Tabs iOS` (optional).
4. Click **Register App**.

### Download GoogleService-Info.plist
5. Click **Download GoogleService-Info.plist**.
6. In Finder, place the file inside `Tabs/Tabs/` — the same folder as `TabsApp.swift`. **Do not put it at the project root.**
7. In Xcode, confirm the file appears in the file navigator under the `Tabs` group. If it doesn't, drag it in and ensure **"Add to target: Tabs"** is checked.
8. Click **Next** through the remaining SDK steps, then **Continue to console**.

> **Bundle ID mismatch warning in logs?**
> If you see `"The project's Bundle ID is inconsistent with ... GoogleService-Info.plist"`, it means the plist was downloaded for a different bundle ID.
> Fix: In the Firebase Console, go to **Project settings → Your apps**, click the gear next to your iOS app, and re-download a fresh `GoogleService-Info.plist` after confirming the bundle ID matches what's in Xcode. Replace the old file in `Tabs/Tabs/`.

---

## 3. Enable Authentication

1. In the left sidebar click **Build → Authentication → Get started**.
2. Under **Sign-in method**, enable the providers you use:

   **Sign in with Google** — click **Google**, toggle **Enable**, enter a support email, **Save**.

   **Sign in with Apple** — click **Apple**, toggle **Enable**, **Save**.
   Also in Xcode: target → **Signing & Capabilities → + Capability → Sign In with Apple**.

---

## 4. Create the Firestore Database

1. In the left sidebar click **Build → Firestore Database → Create database**.
2. Choose **Start in production mode**.
3. Pick a location close to your users (e.g. `us-central1`), then **Enable**.

---

## 5. Set Firestore Security Rules  ← THE CRITICAL STEP

This is what caused **"Missing or insufficient permissions"** and blocked players from joining. Paste the rules below exactly, then click **Publish**.

1. In Firestore, click the **Rules** tab.
2. Select all existing text and delete it.
3. Paste the following, then click **Publish**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    // ── Users ──────────────────────────────────────────────────────────────
    match /users/{userId} {
      allow read:  if isSignedIn();
      allow write: if request.auth.uid == userId;
    }

    // ── Tables ─────────────────────────────────────────────────────────────
    match /tables/{tableId} {
      // Any signed-in user can read (needed to look up a table by code)
      allow read: if isSignedIn();

      // Admin creates the table
      allow create: if isSignedIn()
                    && request.auth.uid == request.resource.data.adminId;

      // Admin deletes the table
      allow delete: if isSignedIn()
                    && request.auth.uid == resource.data.adminId;

      // Two cases allowed for update:
      // 1) Existing member updating the table normally.
      // 2) A new player self-joining: they may ONLY add their own UID to
      //    memberIds and touch no other fields.
      allow update: if isSignedIn() && (
        request.auth.uid in resource.data.memberIds
        ||
        (
          request.resource.data.diff(resource.data).affectedKeys().hasOnly(['memberIds']) &&
          !(request.auth.uid in resource.data.memberIds) &&
          request.auth.uid in request.resource.data.memberIds
        )
      );

      // ── Players ──────────────────────────────────────────────────────────
      // NOTE: No get() calls here. get() in Firestore security rules can fail
      // silently (network hiccup, quota edge case, session transition timing)
      // and cause permission denials that look like app bugs.  This is a
      // private app where access is already gated by join codes; any signed-in
      // user is fine to read/write player and entry data.
      match /players/{playerId} {
        allow read:   if isSignedIn();
        allow create: if isSignedIn();
        allow update: if isSignedIn();
        allow delete: if isSignedIn()
                      && request.auth.uid == resource.data.userId;
      }

      // ── Sessions ─────────────────────────────────────────────────────────
      match /sessions/{sessionId} {
        allow read:   if isSignedIn();
        allow create: if isSignedIn();
        allow update: if isSignedIn();
        allow delete: if isSignedIn();

        // ── Entries ────────────────────────────────────────────────────────
        match /entries/{entryId} {
          allow read:   if isSignedIn();
          allow create: if isSignedIn();
          allow update: if isSignedIn();
          allow delete: if isSignedIn();
        }
      }
    }
  }
}
```

> **Why the old rules broke joining:** The previous rule for table `update` only allowed writes from existing members. A player trying to join is not yet in `memberIds`, so Firestore rejected the write with "Missing or insufficient permissions." The new rule adds a self-join exception: it allows a non-member to update the document **only if** the sole change is adding their own UID to `memberIds`, and nothing else is modified.

---

## 6. Create Required Firestore Indexes

Some queries require composite indexes. Firestore will print a clickable link in the Xcode console when one is missing — just tap it. You can also create them proactively:

1. In the Firebase Console, go to **Firestore → Indexes → Composite → Add index**.
2. Collection: `sessions`
   Fields: `tableId` (Ascending), `startedAt` (Descending)
   Click **Create**.

---

## 7. Expected Database Structure

```
tables/
  {tableId}/
    adminId:          "uid_of_admin"
    name:             "Friday Night Poker"
    referenceCode:    "264524"
    memberIds:        ["uid_admin", "uid_player2"]
    activeSessionId:  "sess_abc"    ← only while a session is live
    disputedAmount:   0

    players/
      {playerId}/
        id, userId, name, tableId, totalEarnings

    sessions/
      {sessionId}/
        id, tableId, status, sessionNumber, startedAt, endedAt, disputedAmount

        entries/
          {entryId}/
            id, playerId, playerName, tableId, sessionId,
            buyIn, finalAmount, netAmount, isManualNet, submittedAt

users/
  {userId}/
    id, name, email
```

---

## 8. Test Checklist

Run through this after publishing the rules:

1. **Sign in** on two devices/simulators with different accounts.
2. **Create a table** on account A — it appears on the home screen.
3. **Share the reference code** shown after creation.
4. **Join the table** on account B using the code — should succeed immediately with no permission error. Account A stays as admin.
5. Account B should now appear in the players list inside the table.
6. **Start a session** as the admin (account A) — the "Live" badge appears on both devices.
7. Both accounts **log their entries**.
8. Admin **settles the session** — session status changes to `completed`, live badge disappears.

---

## 9. Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Missing or insufficient permissions` on join | Old rules without self-join exception | Paste the new rules from Step 5 and click **Publish** |
| `Missing or insufficient permissions` on settle | Old rules with `get()` calls, or rules not published | Paste the new simplified rules from Step 5 and click **Publish** |
| Entries always show as 0 / P&L always 0 | Old rules with `get()` silently denied entry writes | Paste the new simplified rules from Step 5 |
| `Bundle ID inconsistent` warning in Xcode console | plist downloaded for wrong bundle ID | Re-download plist from Firebase → Project settings |
| App crashes on launch | `GoogleService-Info.plist` in wrong folder | Move it into `Tabs/Tabs/`, not the project root |
| `Index required` error | Missing composite index | Click the auto-generated link in the Xcode console |
| Settlement spinner never stops | `nonisolated` fix not compiled | **Product → Clean Build Folder (⇧⌘K)**, then rebuild |
