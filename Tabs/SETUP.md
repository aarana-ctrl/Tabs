# Tabs – Setup Guide

## Files to Add to Your Xcode Project

Drag all `.swift` files from this folder into your Xcode project, replacing the existing `ContentView.swift`, `TabsApp.swift`, and `Persistence.swift`. Delete `Persistence.swift` entirely — it is no longer needed.

---

## 1. Firebase Project Setup

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project (or use your existing one)
3. Enable **Firestore Database** (start in test mode for development)
4. Enable **Firebase Authentication** → Sign-in method → enable **Apple** and **Google**

---

## 2. Add Your iOS App to Firebase

1. In Firebase Console → Project Settings → Add App → iOS
2. Enter your Bundle ID (e.g. `com.yourname.Tabs`)
3. Download `GoogleService-Info.plist`
4. Drag `GoogleService-Info.plist` into your Xcode project root
   ✅ Check "Copy items if needed"
   ✅ Check your app target in "Add to targets"

---

## 3. Swift Package Dependencies

### Firebase (firebase-ios-sdk)
1. Xcode → File → Add Package Dependencies
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: **Up to Next Major**
4. Add these products to your target:
   - `FirebaseCore`
   - `FirebaseAuth`
   - `FirebaseFirestore`

> `FirebaseFirestoreSwift` is no longer a separate product — Codable support is built into `FirebaseFirestore` since SDK v10.

### Google Sign-In (GoogleSignIn-iOS)
1. Xcode → File → Add Package Dependencies
2. URL: `https://github.com/google/GoogleSignIn-iOS`
3. Version: **Up to Next Major**
4. Add these products to your target:
   - `GoogleSignIn`
   - `GoogleSignInSwift`

---

## 4. Add Sign in with Apple Capability

1. Select your project in the Xcode navigator
2. Select your app **Target**
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** → search for and add **Sign in with Apple**

---

## 5. Add the Google Sign-In URL Scheme

This lets Google redirect back to your app after sign-in.

1. Open `GoogleService-Info.plist` in a text editor or Xcode
2. Find the value for `REVERSED_CLIENT_ID`
   It looks like: `com.googleusercontent.apps.XXXXXXXXX-YYYYYYY`
3. In Xcode → select your Target → **Info** tab → **URL Types** → click **+**
4. Set **URL Schemes** to your `REVERSED_CLIENT_ID` value
   Leave Identifier blank or set it to `GoogleSignIn`

---

## 6. Remove CoreData

The app no longer uses CoreData:
- Delete `Tabs.xcdatamodeld` from the project navigator
- Delete `Persistence.swift`

---

## 7. Set the App Icon

1. Open `Assets.xcassets` in Xcode
2. Click **AppIcon**
3. Drag your poker cards image into the **1024×1024** "App Store" slot
   Xcode will automatically scale it to all required sizes
4. Alternatively, use an icon generator tool (e.g. [appicon.co](https://www.appicon.co)) to export all sizes at once, then drag the whole `AppIcon.appiconset` folder into your Assets

---

## 8. Firestore Security Rules (for production)

In Firebase Console → Firestore → Rules, replace with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /tables/{tableId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
      match /players/{playerId} {
        allow read, write: if request.auth != null;
      }
      match /sessions/{sessionId} {
        allow read, write: if request.auth != null;
        match /entries/{entryId} {
          allow read, write: if request.auth != null;
        }
      }
    }
  }
}
```

---

## Architecture Overview

```
TabsApp (entry point — configures Firebase + GIDSignIn)
  └── ContentView (auth gate — listens to Firebase Auth state)
        ├── LoginView          — Sign in with Apple / Google → Firebase Auth
        └── HomeView           — list of joined tables
              ├── JoinTableView (sheet)
              ├── CreateTableView (sheet)
              └── TableDetailView
                    ├── LeaderboardView (sheet)
                    ├── LogEntryView (sheet)
                    ├── SessionView (sheet)
                    │     └── SettlementView (sheet)
                    └── PlayerDetailView
                          └── LogEntryView (sheet)
```

**Auth flow:**
Sign in with Apple/Google → Firebase Auth creates/retrieves user → `AppViewModel` auth state listener fires → user profile saved/fetched from Firestore → app unlocks.

**Real-time sync:** Player earnings and session entries use Firestore snapshot listeners, so changes on one device appear instantly on all others in the same table.

---

## Requirements

- iOS 16+ (Swift Charts, NavigationStack)
- Xcode 15+
- Firebase iOS SDK 10+
- GoogleSignIn-iOS SDK 7+
