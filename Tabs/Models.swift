//
//  Models.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import Foundation

// MARK: - App User

struct AppUser: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var email: String

    init(id: String = UUID().uuidString, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

// MARK: - Poker Table

struct PokerTable: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var adminId: String
    /// Additional admins promoted by the original admin.
    var coAdminIds: [String]
    var referenceCode: String
    var memberIds: [String]
    var disputedAmount: Double
    var createdAt: Date
    var activeSessionId: String?
    /// True while the admin has an active table-level settlement in progress.
    var isInSettlement: Bool
    /// Player document IDs that the admin has marked as paid/received during settlement.
    var settledPlayerIds: [String]

    // MARK: - Designated init

    init(
        id: String = UUID().uuidString,
        name: String,
        adminId: String,
        coAdminIds: [String] = [],
        referenceCode: String = String(Int.random(in: 100000...999999)),
        memberIds: [String] = [],
        disputedAmount: Double = 0,
        createdAt: Date = Date(),
        activeSessionId: String? = nil,
        isInSettlement: Bool = false,
        settledPlayerIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.adminId = adminId
        self.coAdminIds = coAdminIds
        self.referenceCode = referenceCode
        self.memberIds = memberIds
        self.disputedAmount = disputedAmount
        self.createdAt = createdAt
        self.activeSessionId = activeSessionId
        self.isInSettlement = isInSettlement
        self.settledPlayerIds = settledPlayerIds
    }

    // MARK: - Codable
    //
    // Custom decoder so that documents created before new fields were introduced
    // still decode correctly.  Swift's synthesised init(from:) throws
    // `keyNotFound` for any missing key, causing fetchTables to fail silently
    // and leave `tables` empty after every logout/login cycle.

    enum CodingKeys: String, CodingKey {
        case id, name, adminId, coAdminIds, referenceCode, memberIds,
             disputedAmount, createdAt, activeSessionId,
             isInSettlement, settledPlayerIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try  c.decode(String.self,    forKey: .id)
        name             = try  c.decode(String.self,    forKey: .name)
        adminId          = try  c.decode(String.self,    forKey: .adminId)
        // Fields added after initial launch — default to safe values when absent
        coAdminIds       = (try? c.decode([String].self, forKey: .coAdminIds))      ?? []
        disputedAmount   = (try? c.decode(Double.self,   forKey: .disputedAmount))  ?? 0
        isInSettlement   = (try? c.decode(Bool.self,     forKey: .isInSettlement))  ?? false
        settledPlayerIds = (try? c.decode([String].self, forKey: .settledPlayerIds)) ?? []
        referenceCode    = try  c.decode(String.self,    forKey: .referenceCode)
        memberIds        = try  c.decode([String].self,  forKey: .memberIds)
        createdAt        = try  c.decode(Date.self,      forKey: .createdAt)
        activeSessionId  = try? c.decode(String.self,   forKey: .activeSessionId)
    }

    // MARK: - Computed

    var hasActiveSession: Bool { activeSessionId != nil }

    /// Returns true if the given userId has any admin privileges.
    func isAdmin(_ userId: String) -> Bool {
        userId == adminId || coAdminIds.contains(userId)
    }
}

// MARK: - Table Player

struct TablePlayer: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var userId: String
    var name: String
    /// Current-cycle P/L — resets to 0 when admin closes a table settlement.
    var totalEarnings: Double
    /// Cumulative all-time P/L — never resets; incremented by totalEarnings at each close.
    var lifetimeEarnings: Double
    var tableId: String
    var joinedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        totalEarnings: Double = 0,
        lifetimeEarnings: Double = 0,
        tableId: String,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.totalEarnings = totalEarnings
        self.lifetimeEarnings = lifetimeEarnings
        self.tableId = tableId
        self.joinedAt = joinedAt
    }

    // Custom decoder so documents created before lifetimeEarnings existed
    // still decode correctly (defaults to 0 when key is absent).
    enum CodingKeys: String, CodingKey {
        case id, userId, name, totalEarnings, lifetimeEarnings, tableId, joinedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try  c.decode(String.self, forKey: .id)
        userId           = try  c.decode(String.self, forKey: .userId)
        name             = try  c.decode(String.self, forKey: .name)
        totalEarnings    = (try? c.decode(Double.self, forKey: .totalEarnings))   ?? 0
        lifetimeEarnings = (try? c.decode(Double.self, forKey: .lifetimeEarnings)) ?? 0
        tableId          = try  c.decode(String.self, forKey: .tableId)
        joinedAt         = try  c.decode(Date.self,   forKey: .joinedAt)
    }
}

// MARK: - Game Session

struct GameSession: Identifiable, Codable, Equatable {
    var id: String
    var tableId: String
    var startedAt: Date
    var endedAt: Date?
    var status: SessionStatus
    var disputedAmount: Double
    var sessionNumber: Int

    enum SessionStatus: String, Codable, Equatable {
        case active
        case settling   // waiting for all entries
        case completed
        case disputed
    }

    init(
        id: String = UUID().uuidString,
        tableId: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: SessionStatus = .active,
        disputedAmount: Double = 0,
        sessionNumber: Int = 1
    ) {
        self.id = id
        self.tableId = tableId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.disputedAmount = disputedAmount
        self.sessionNumber = sessionNumber
    }
}

// MARK: - Session Entry

struct SessionEntry: Identifiable, Codable, Equatable {
    var id: String
    var sessionId: String
    var tableId: String
    var playerId: String
    var playerName: String
    var buyIn: Double
    var finalAmount: Double
    var netAmount: Double          // finalAmount - buyIn  (or directly provided)
    var submittedAt: Date
    var isManualNet: Bool          // true if user just typed net directly

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        tableId: String,
        playerId: String,
        playerName: String,
        buyIn: Double,
        finalAmount: Double,
        netAmount: Double,
        submittedAt: Date = Date(),
        isManualNet: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.tableId = tableId
        self.playerId = playerId
        self.playerName = playerName
        self.buyIn = buyIn
        self.finalAmount = finalAmount
        self.netAmount = netAmount
        self.submittedAt = submittedAt
        self.isManualNet = isManualNet
    }
}

// MARK: - Settlement Resolution

enum DisputeResolution {
    case disputeFund
    case splitEvenly
}

// MARK: - Cross-table Analytics

struct TableAnalyticsStat: Identifiable {
    var id: String { table.id }
    let table: PokerTable
    let player: TablePlayer
    let entries: [SessionEntry]

    // Stored once at init — computed properties on a value type re-evaluate
    // on every access, which multiplies work across all SwiftUI render passes.
    let totalEarnings: Double
    let sessionCount: Int
    let bestSession: Double
    let worstSession: Double
    let winRate: Double

    init(table: PokerTable, player: TablePlayer, entries: [SessionEntry]) {
        self.table   = table
        self.player  = player
        self.entries = entries

        self.sessionCount   = entries.count
        self.totalEarnings  = entries.reduce(0) { $0 + $1.netAmount }
        self.bestSession    = entries.map { $0.netAmount }.max() ?? 0
        self.worstSession   = entries.map { $0.netAmount }.min() ?? 0
        let wins = entries.filter { $0.netAmount > 0 }.count
        self.winRate = entries.isEmpty ? 0 : Double(wins) / Double(entries.count)
    }
}
