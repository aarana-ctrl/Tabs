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
    var referenceCode: String
    var memberIds: [String]
    var disputedAmount: Double
    var createdAt: Date
    var activeSessionId: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        adminId: String,
        referenceCode: String = String(Int.random(in: 100000...999999)),
        memberIds: [String] = [],
        disputedAmount: Double = 0,
        createdAt: Date = Date(),
        activeSessionId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.adminId = adminId
        self.referenceCode = referenceCode
        self.memberIds = memberIds
        self.disputedAmount = disputedAmount
        self.createdAt = createdAt
        self.activeSessionId = activeSessionId
    }

    var hasActiveSession: Bool { activeSessionId != nil }
}

// MARK: - Table Player

struct TablePlayer: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var userId: String
    var name: String
    var totalEarnings: Double
    var tableId: String
    var joinedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        totalEarnings: Double = 0,
        tableId: String,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.totalEarnings = totalEarnings
        self.tableId = tableId
        self.joinedAt = joinedAt
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
