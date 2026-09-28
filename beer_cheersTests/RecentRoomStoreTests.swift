//
//  RecentRoomStoreTests.swift
//  beer_cheersTests
//

import Foundation
import Testing
@testable import beer_cheers

final class RecentRoomStoreTests {
    private let suiteName = "RecentRoomStoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        // deinit は MainActor 外で走るため、非 Sendable の `defaults` ではなく Sendable な suiteName から消す
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func newestRoomComesFirst() {
        RecentRoomStore.record("a", defaults: defaults)
        RecentRoomStore.record("b", defaults: defaults)

        #expect(RecentRoomStore.load(defaults: defaults) == ["b", "a"])
    }

    @Test func revisitingRoomMovesItToTopWithoutDuplicates() {
        RecentRoomStore.record("a", defaults: defaults)
        RecentRoomStore.record("b", defaults: defaults)
        RecentRoomStore.record("a", defaults: defaults)

        #expect(RecentRoomStore.load(defaults: defaults) == ["a", "b"])
    }

    @Test func keepsOnlyTheMostRecentRooms() {
        for index in 0...RecentRoomStore.maxCount {
            RecentRoomStore.record("room\(index)", defaults: defaults)
        }

        let rooms = RecentRoomStore.load(defaults: defaults)
        #expect(rooms.count == RecentRoomStore.maxCount)
        #expect(rooms.first == "room\(RecentRoomStore.maxCount)")
        #expect(!rooms.contains("room0"))
    }

    @Test func guestRoomIsNotRecorded() {
        RecentRoomStore.record(RoomSessionStore.makeGuestRoomID(), defaults: defaults)

        #expect(RecentRoomStore.load(defaults: defaults).isEmpty)
    }

    @Test func removedRoomDisappears() {
        RecentRoomStore.record("a", defaults: defaults)
        RecentRoomStore.record("b", defaults: defaults)

        RecentRoomStore.remove("a", defaults: defaults)

        #expect(RecentRoomStore.load(defaults: defaults) == ["b"])
    }
}
