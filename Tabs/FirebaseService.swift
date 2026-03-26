//
//  FirebaseService.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//
//  Requires: Firebase iOS SDK via Swift Package Manager
//  Package URL: https://github.com/firebase/firebase-ios-sdk
//  Products to add: FirebaseCore, FirebaseFirestore
//
//  IMPORTANT — Swift 6 / Xcode 26 concurrency note:
//  When SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor is set in build settings,
//  every class is implicitly @MainActor.  Calling Firebase's own async/await
//  APIs from @MainActor can deadlock because Firestore dispatches internal
//  completion handlers back to the main queue, which is blocked waiting for
//  itself.  Marking all stored properties nonisolated(unsafe) and every method
//  nonisolated removes the @MainActor requirement from this service so Firestore
//  can use whichever queue it needs internally.
//

import Foundation
import FirebaseFirestore

class FirebaseService {

    nonisolated(unsafe) static let shared = FirebaseService()
    nonisolated(unsafe) private let db = Firestore.firestore()

    private init() {}

    // MARK: - Collections

    private nonisolated var usersRef:   CollectionReference { db.collection("users") }
    private nonisolated var tablesRef:  CollectionReference { db.collection("tables") }

    private nonisolated func playersRef(tableId: String) -> CollectionReference {
        tablesRef.document(tableId).collection("players")
    }
    private nonisolated func sessionsRef(tableId: String) -> CollectionReference {
        tablesRef.document(tableId).collection("sessions")
    }
    private nonisolated func entriesRef(tableId: String, sessionId: String) -> CollectionReference {
        sessionsRef(tableId: tableId).document(sessionId).collection("entries")
    }

    // MARK: - Users

    nonisolated func saveUser(_ user: AppUser) async throws {
        try usersRef.document(user.id).setData(from: user, merge: true)
    }

    nonisolated func fetchUser(id: String) async throws -> AppUser? {
        let doc = try await usersRef.document(id).getDocument()
        return try doc.data(as: AppUser.self)
    }

    // MARK: - Tables

    nonisolated func createTable(_ table: PokerTable) async throws {
        try tablesRef.document(table.id).setData(from: table)
    }

    nonisolated func fetchTables(for userId: String) async throws -> [PokerTable] {
        let snapshot = try await tablesRef
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: PokerTable.self) }
    }

    nonisolated func fetchTable(id: String) async throws -> PokerTable? {
        let doc = try await tablesRef.document(id).getDocument()
        return try doc.data(as: PokerTable.self)
    }

    nonisolated func fetchTableByCode(_ code: String) async throws -> PokerTable? {
        let snapshot = try await tablesRef
            .whereField("referenceCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.flatMap { try $0.data(as: PokerTable.self) }
    }

    nonisolated func updateTable(_ table: PokerTable) async throws {
        try tablesRef.document(table.id).setData(from: table, merge: true)
    }

    nonisolated func deleteTable(tableId: String) async throws {
        try await tablesRef.document(tableId).delete()
    }

    nonisolated func addMember(userId: String, to tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
    }

    nonisolated func updateDisputedAmount(_ amount: Double, tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "disputedAmount": FieldValue.increment(amount)
        ])
    }

    nonisolated func setDisputedAmount(_ amount: Double, tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "disputedAmount": amount
        ])
    }

    nonisolated func updateCoAdmins(tableId: String, coAdminIds: [String]) async throws {
        try await tablesRef.document(tableId).updateData([
            "coAdminIds": coAdminIds
        ])
    }

    // MARK: - Disputed sessions
    //
    // Previously fetched ALL sessions then filtered client-side.  Now queries
    // only sessions with status == "disputed" — avoids downloading all session
    // documents on every DisputeFundView open.

    nonisolated func fetchDisputedSessions(tableId: String) async throws -> [GameSession] {
        let snapshot = try await sessionsRef(tableId: tableId)
            .whereField("status", isEqualTo: GameSession.SessionStatus.disputed.rawValue)
            .getDocuments()
        return try snapshot.documents
            .compactMap { try $0.data(as: GameSession.self) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Table Settlement

    nonisolated func startTableSettlement(tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "isInSettlement":   true,
            "settledPlayerIds": []
        ])
    }

    nonisolated func cancelTableSettlement(tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "isInSettlement":   false,
            "settledPlayerIds": []
        ])
    }

    nonisolated func setPlayerSettled(playerId: String, tableId: String, isSettled: Bool) async throws {
        try await tablesRef.document(tableId).updateData([
            "settledPlayerIds": isSettled
                ? FieldValue.arrayUnion([playerId])
                : FieldValue.arrayRemove([playerId])
        ])
    }

    /// Closes settlement atomically: archives every player's cycle earnings
    /// into lifetimeEarnings, zeros totalEarnings, and clears table flags —
    /// all in one batch commit so no partial state is ever visible.
    nonisolated func closeTableSettlement(tableId: String, players: [TablePlayer]) async throws {
        let batch = db.batch()
        for player in players {
            let ref = playersRef(tableId: tableId).document(player.id)
            batch.updateData([
                "lifetimeEarnings": player.lifetimeEarnings + player.totalEarnings,
                "totalEarnings":    0.0
            ], forDocument: ref)
        }
        batch.updateData([
            "isInSettlement":   false,
            "settledPlayerIds": []
        ], forDocument: tablesRef.document(tableId))
        try await batch.commit()
    }

    // MARK: - Players

    nonisolated func addPlayer(_ player: TablePlayer) async throws {
        try playersRef(tableId: player.tableId).document(player.id).setData(from: player)
    }

    nonisolated func fetchPlayers(tableId: String) async throws -> [TablePlayer] {
        let snapshot = try await playersRef(tableId: tableId).getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: TablePlayer.self) }
    }

    nonisolated func updatePlayerEarnings(playerId: String, tableId: String, delta: Double) async throws {
        try await playersRef(tableId: tableId).document(playerId).updateData([
            "totalEarnings": FieldValue.increment(delta)
        ])
    }

    /// Applies a batch of (playerId, delta) earnings updates in a single
    /// Firestore commit instead of N sequential round trips.
    nonisolated func batchUpdatePlayerEarnings(
        _ deltas: [(playerId: String, delta: Double)],
        tableId: String
    ) async throws {
        guard !deltas.isEmpty else { return }
        let batch = db.batch()
        for (playerId, delta) in deltas where delta != 0 {
            batch.updateData(
                ["totalEarnings": FieldValue.increment(delta)],
                forDocument: playersRef(tableId: tableId).document(playerId)
            )
        }
        try await batch.commit()
    }

    nonisolated func fetchPlayer(playerId: String, tableId: String) async throws -> TablePlayer? {
        let doc = try await playersRef(tableId: tableId).document(playerId).getDocument()
        return try doc.data(as: TablePlayer.self)
    }

    nonisolated func fetchSession(sessionId: String, tableId: String) async throws -> GameSession? {
        let doc = try await sessionsRef(tableId: tableId).document(sessionId).getDocument()
        return try? doc.data(as: GameSession.self)
    }

    nonisolated func fetchMyPlayer(tableId: String, userId: String) async throws -> TablePlayer? {
        let snapshot = try await playersRef(tableId: tableId)
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.flatMap { try $0.data(as: TablePlayer.self) }
    }

    // MARK: - Sessions

    nonisolated func createSession(_ session: GameSession) async throws {
        try sessionsRef(tableId: session.tableId).document(session.id).setData(from: session)
        try await tablesRef.document(session.tableId).updateData([
            "activeSessionId": session.id
        ])
    }

    /// Returns the total number of sessions for a table using a server-side
    /// aggregation count — avoids downloading all session documents.
    nonisolated func countSessions(tableId: String) async throws -> Int {
        let result = try await sessionsRef(tableId: tableId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: result.count)
    }

    nonisolated func fetchSessions(tableId: String) async throws -> [GameSession] {
        let snapshot = try await sessionsRef(tableId: tableId)
            .order(by: "startedAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: GameSession.self) }
    }

    nonisolated func updateSession(_ session: GameSession) async throws {
        try sessionsRef(tableId: session.tableId).document(session.id).setData(from: session, merge: true)
    }

    /// Deletes all entries for a session and resets it to active status in a
    /// single batch commit instead of N sequential delete() calls.
    nonisolated func resetSession(sessionId: String, tableId: String) async throws {
        let snapshot = try await entriesRef(tableId: tableId, sessionId: sessionId).getDocuments()
        if !snapshot.documents.isEmpty {
            let batch = db.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        try await sessionsRef(tableId: tableId).document(sessionId).updateData([
            "status":          GameSession.SessionStatus.active.rawValue,
            "disputedAmount":  0.0
        ])
    }

    /// Settles a session atomically using a single batch commit:
    /// – all player earnings deltas
    /// – session status + endedAt + disputedAmount
    /// – table activeSessionId cleared
    /// – table disputedAmount incremented (when logging to fund)
    ///
    /// Previously required N+3 sequential Firestore round trips.
    nonisolated func settleSessionBatch(
        sessionId: String,
        tableId: String,
        status: GameSession.SessionStatus,
        sessionDisputedAmount: Double,
        earningDeltas: [(playerId: String, delta: Double)],
        tableDisputeDelta: Double
    ) async throws {
        let batch = db.batch()

        // Player earnings (skip zero-delta rows)
        for (playerId, delta) in earningDeltas where delta != 0 {
            batch.updateData(
                ["totalEarnings": FieldValue.increment(delta)],
                forDocument: playersRef(tableId: tableId).document(playerId)
            )
        }

        // Session document
        batch.updateData([
            "status":          status.rawValue,
            "endedAt":         Timestamp(date: Date()),
            "disputedAmount":  sessionDisputedAmount
        ], forDocument: sessionsRef(tableId: tableId).document(sessionId))

        // Table document — clear active session + optionally add to fund
        var tableUpdate: [String: Any] = ["activeSessionId": FieldValue.delete()]
        if tableDisputeDelta != 0 {
            tableUpdate["disputedAmount"] = FieldValue.increment(tableDisputeDelta)
        }
        batch.updateData(tableUpdate, forDocument: tablesRef.document(tableId))

        try await batch.commit()
    }

    // MARK: - Session Entries

    nonisolated func submitEntry(_ entry: SessionEntry) async throws {
        try entriesRef(tableId: entry.tableId, sessionId: entry.sessionId)
            .document(entry.id)
            .setData(from: entry)
    }

    nonisolated func fetchEntries(tableId: String, sessionId: String) async throws -> [SessionEntry] {
        let snapshot = try await entriesRef(tableId: tableId, sessionId: sessionId).getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: SessionEntry.self) }
    }

    /// Fetches a player's entry history across all completed/disputed sessions.
    ///
    /// Previously looped sequentially over every session (O(S) round trips).
    /// Now fires all per-session queries concurrently with a throwing task
    /// group, reducing wall-clock time from S×RTT to ~1×RTT regardless of
    /// how many sessions exist.
    nonisolated func fetchAllEntries(tableId: String, playerId: String) async throws -> [SessionEntry] {
        let sessions = try await fetchSessions(tableId: tableId)
        let eligible = sessions.filter { $0.status == .completed || $0.status == .disputed }
        guard !eligible.isEmpty else { return [] }

        let allEntries = try await withThrowingTaskGroup(of: [SessionEntry].self) { group in
            for session in eligible {
                group.addTask { [self] in
                    let snapshot = try await self.entriesRef(tableId: tableId, sessionId: session.id)
                        .whereField("playerId", isEqualTo: playerId)
                        .getDocuments()
                    return try snapshot.documents.compactMap { try $0.data(as: SessionEntry.self) }
                }
            }
            var results: [SessionEntry] = []
            for try await batch in group { results.append(contentsOf: batch) }
            return results
        }
        return allEntries.sorted { $0.submittedAt < $1.submittedAt }
    }

    // MARK: - Listeners

    nonisolated func listenToPlayers(
        tableId: String,
        onChange: @escaping ([TablePlayer]) -> Void
    ) -> ListenerRegistration {
        playersRef(tableId: tableId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let players = (try? snapshot.documents.compactMap { try $0.data(as: TablePlayer.self) }) ?? []
            onChange(players)
        }
    }

    nonisolated func listenToTable(
        tableId: String,
        onChange: @escaping (PokerTable?) -> Void
    ) -> ListenerRegistration {
        tablesRef.document(tableId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let table = try? snapshot.data(as: PokerTable.self)
            onChange(table)
        }
    }

    nonisolated func listenToEntries(
        tableId: String,
        sessionId: String,
        onChange: @escaping ([SessionEntry]) -> Void
    ) -> ListenerRegistration {
        entriesRef(tableId: tableId, sessionId: sessionId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let entries = (try? snapshot.documents.compactMap { try $0.data(as: SessionEntry.self) }) ?? []
            onChange(entries)
        }
    }
}
