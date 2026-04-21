# Tabs — Poker Tracking App

Tabs is a cross-platform poker session tracker for friend groups. It keeps a running ledger of the profits and loss of players across sessions, handles guest players, manages settlements, and gives each player a full history of their results — all synced in real time between the iOS app and the web app.

---

## Platforms

iOS : SwiftUI + Firebase iOS SDK
Web : React 18 + TypeScript + Vite + Tailwind CSS

** Web app repo is private for security reasons. The link to the website is : https://tabs-web.vercel.app **

Both apps share the same Firestore database, so any action taken on one platform is immediately reflected on the other.

---

## Features

### Tables
A **table** represents a recurring poker group. Each table has a unique reference code that members use to join. One player is the **Admin** and can optionally designate **Co-Admins**.

- Create a new table or join one with a reference code
- Persistent leaderboard showing each member's all-time P&L
- Admin and Co-Admin badges shown next to names on the leaderboard
- Session history page (admin only) listing every session and each player's result

### Sessions
A session is a single poker night. Sessions are started and managed from the table page.

- Players log their own buy-in and final chip amount at the end of the night
- The session page shows a live balance bar — the total net must be $0 before settlement
- Admin can edit any submitted entry at any time, including retroactively
- Guests (non-members) can be added to a session with a name and net P&L

### Guests
Guests are one-off players who don't have accounts. Their results count toward the session balance but do not appear on the main leaderboard. Each guest's all-time P&L is tracked and shown in the Guests section of the table.

### Settlements
When a session ends, the admin initiates **settlement mode**. Each player marks themselves as settled once cash has changed hands. When all players are settled, the admin closes the session.

### Player Profiles
Tapping any player opens their profile, which shows:
- Total earnings broken down as **Session Total + Distributed** (if applicable)
- Full session-by-session history with net P&L per session
- Win rate and best/worst session stats

### Admin Controls
Admins have a dedicated panel with elevated abilities:

1. Edit any session entry : Correct a buy-in or final amount after the fact
2. Distribute a player's P&L : Zero out a player's balance and split it evenly among the remaining players.
3. Remove a player from the table : Choose to split their balance among remaining players or move it to the dispute fund.
4. Dispute Fund : A running pool of funds from removed players or contested amounts. Admin can split it evenly among current players or clear it.
5. Session History : View every session sorted newest-first, tap into individual entries, and edit anything inline.

### Analytics
The Analytics page shows a player's personal stats rolled up across all tables they belong to: cumulative P&L chart, per-session breakdown, win rate, and best/worst session.

---

## Data Model (Firestore)

```
tables/{tableId}
  ├── sessions/{sessionId}
  │     └── entries/{entryId}
  └── players/{playerId}
        guests/{guestId}
              └── guestEntries/{guestEntryId}
```

---
## Project Structure

tabs-web/src/
  components/
    layout/       # AppLayout, nav bar
    ui/           # Button, Card, Input, Modal, Toggle, misc atoms
  context/
    AppContext.tsx # Global state (Zustand-backed), all async actions
  firebase/
    service.ts    # All Firestore read/write functions
  types/
    models.ts     # TypeScript interfaces and helpers
  views/          # One file per screen/modal

Tabs/ (iOS)
  Models.swift
  FirebaseService.swift
  AppViewModel.swift
  *View.swift     # One file per screen


---

## Auth

Authentication uses **Firebase Anonymous Auth** — players sign in with a display name and are assigned a persistent anonymous UID. No email or password required.

---

## Screenshots

Example screenshots from the app. Some detailed have been blacked out for privacy reasons. 

<img width="1206" height="2626" alt="test" src="https://github.com/user-attachments/assets/291306d9-42de-4d81-bd79-4c3760e3de39" />


<img width="1206" height="2622" alt="test" src="https://github.com/user-attachments/assets/67a4ec9b-e5bf-498f-a78d-84d71157416e" />


<img width="1206" height="2624" alt="test-5" src="https://github.com/user-attachments/assets/e4ec8d54-3353-4e85-ad85-b09da45ad550" />


<img width="1206" height="2630" alt="test-4" src="https://github.com/user-attachments/assets/2f74b7df-afbe-4b8b-9a4a-f73c8abcb854" />


<img width="1206" height="2622" alt="test-3" src="https://github.com/user-attachments/assets/5121d87d-a559-4d73-b8b3-ad9233b0f6ca" />


<img width="1206" height="2622" alt="test-2" src="https://github.com/user-attachments/assets/87ca8931-4049-4d9a-8526-25ccdc3b84fe" />
