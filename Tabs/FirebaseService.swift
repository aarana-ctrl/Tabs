//
//  FirebaseService.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//
//  Requires: Firebase iOS SDK via Swift Package Manager
//  Package URL: https://github.com/firebase/firebase-ios-sdk
//  Products to add: FirebaseCore, FirebaseFirestore
//  Note: Codable support (setData(from:), data(as:)) is built into
//  FirebaseFirestore in SDK v10+ — no separate package needed.
//

import Foundation
import FirebaseFirestore

class FirebaseService {

    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Collections

    private var usersRef: CollectionReference { db.collection("users") }
    private var tablesRef: CollectionReference { db.collection("tables") }

    private func playersRef(tableId: String) -> CollectionReference {
        tablesRef.document(tableId).collection("players")
    }
    private func sessionsRef(tableId: String) -> CollectionReference {
        tablesRef.document(tableId).collection("sessions")
    }
    private func entriesRef(tableId: String, sessionId: String) -> CollectionReference {
        sessionsRef(tableId: tableId).document(sessionId).collection("entries")
    }

    // MARK: - Users

    func saveUser(_ user: AppUser) async throws {
        try usersRef.document(user.id).setData(from: user, merge: true)
    }

    func fetchUser(id: String) async throws -> AppUser? {
        let doc = try await usersRef.document(id).getDocument()
        return try doc.data(as: AppUser.self)
    }

    // MARK: - Tables

    func createTable(_ table: PokerTable) async throws {
        try tablesRef.document(table.id).setData(from: table)
    }

    func fetchTables(for userId: String) async throws -> [PokerTable] {
        let snapshot = try await tablesRef
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: PokerTable.self) }
    }

    func fetchTable(id: String) async throws -> PokerTable? {
        let doc = try await tablesRef.document(id).getDocument()
        return try doc.data(as: PokerTable.self)
    }

    func fetchTableByCode(_ code: String) async throws -> PokerTable? {
        let snapshot = try await tablesRef
            .whereField("referenceCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.flatMap { try $0.data(as: PokerTable.self) }
    }

    func updateTable(_ table: PokerTable) async throws {
        try tablesRef.document(table.id).setData(from: table, merge: true)
    }

    func addMember(userId: String, to tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
    }

    func updateDisputedAmount(_ amount: Double, tableId: String) async throws {
        try await tablesRef.document(tableId).updateData([
            "disputedAmount": FieldValue.increment(amount)
        ])
    }

    // MARK: - Players

    func addPlayer(_ player: TablePlayer) async throws {
        try playersRef(tableId: player.tableId).document(player.id).setData(from: player)
    }

    func fetchPlayers(tableId: String) async throws -> [TablePlayer] {
        let snapshot = try await playersRef(tableId: tableId).getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: TablePlayer.self) }
    }

    func updatePlayerEarnings(playerId: String, tableId: String, delta: Double) async throws {
        try await playersRef(tableId: tableId).document(playerId).updateData([
            "totalEarnings": FieldValue.increment(delta)
        ])
    }

    func fetchPlayer(playerId: String, tableId: String) async throws -> TablePlayer? {
        let doc = try await playersRef(tableId: tableId).document(playerId).getDocument()
        return try doc.data(as: TablePlayer.self)
    }

    // MARK: - Sessions

    func createSession(_ session: GameSession) async throws {
        try sessionsRef(tableId: session.tableId).document(session.id).setData(from: session)
        // Also set activeSessionId on the table
        try await tablesRef.document(session.tableId).updateData([
            "activeSessionId": session.id
        ])
    }

    func fetchSessions(tableId: String) async throws -> [GameSession] {
        let snapshot = try await sessionsRef(tableId: tableId)
            .order(by: "startedAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: GameSession.self) }
    }

    func updateSession(_ session: GameSession) async throws {
        try sessionsRef(tableId: session.tableId).document(session.id).setData(from: session, merge: true)
    }

    func closeSession(sessionId: String, tableId: String, status: GameSession.SessionStatus, disputedAmount: Double) async throws {
        try await sessionsRef(tableId: tableId).document(sessionId).updateData([
            "status": status.rawValue,
            "endedAt": Timestamp(date: Date()),
            "disputedAmount": disputedAmount
        ])
        try await tablesRef.document(tableId).updateData([
            "activeSessionId": FieldValue.delete()
        ])
    }

    // MARK: - Session Entries

    func submitEntry(_ entry: SessionEntry) async throws {
        try entriesRef(tableId: entry.tableId, sessionId: entry.sessionId)
            .document(entry.id)
            .setData(from: entry)
    }

    func fetchEntries(tableId: String, sessionId: String) async throws -> [SessionEntry] {
        let snapshot = try await entriesRef(tableId: tableId, sessionId: sessionId).getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: SessionEntry.self) }
    }

    func fetchAllEntries(tableId: String, playerId: String) async throws -> [SessionEntry] {
        // Fetch all sessions then query entries per session for the player
        let sessions = try await fetchSessions(tableId: tableId)
        var allEntries: [SessionEntry] = []
        for session in sessions where session.status == .completed || session.status == .disputed {
            let snapshot = try await entriesRef(tableId: tableId, sessionId: session.id)
                .whereField("playerId", isEqualTo: playerId)
                .getDocuments()
            let entries = try snapshot.documents.compactMap { try $0.data(as: SessionEntry.self) }
            allEntries.append(contentsOf: entries)
        }
        return allEntries.sorted { $0.submittedAt < $1.submittedAt }
    }

    // MARK: - Listeners

    func listenToPlayers(tableId: String, onChange: @escaping ([TablePlayer]) -> Void) -> ListenerRegistration {
        playersRef(tableId: tableId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let players = (try? snapshot.documents.compactMap { try $0.data(as: TablePlayer.self) }) ?? []
            onChange(players)
        }
    }

    func listenToTable(tableId: String, onChange: @escaping (PokerTable?) -> Void) -> ListenerRegistration {
        tablesRef.document(tableId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let table = try? snapshot.data(as: PokerTable.self)
            onChange(table)
        }
    }

    func listenToEntries(tableId: String, sessionId: String, onChange: @escaping ([SessionEntry]) -> Void) -> ListenerRegistration {
        entriesRef(tableId: tableId, sessionId: sessionId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let entries = (try? snapshot.documents.compactMap { try $0.data(as: SessionEntry.self) }) ?? []
            onChange(entries)
        }
    }
}
