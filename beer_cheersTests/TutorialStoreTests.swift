//
//  TutorialStoreTests.swift
//  beer_cheersTests
//

import Foundation
import Testing
@testable import beer_cheers

/// テストごとに使い捨ての UserDefaults を使い、実機の保存値や他のテストに影響させない。
final class TutorialStoreTests {
    private let suiteName = "TutorialStoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        // deinit は MainActor 外で走るため、非 Sendable の `defaults` ではなく Sendable な suiteName から消す
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func isNotCompletedInitially() {
        #expect(!TutorialStore.hasCompleted(defaults: defaults))
    }

    @Test func markCompletedPersists() {
        TutorialStore.markCompleted(defaults: defaults)
        #expect(TutorialStore.hasCompleted(defaults: defaults))
    }

    @Test func existingUserIsMarkedCompleted() {
        TutorialStore.skipForExistingUserOnce(isExistingUser: true, defaults: defaults)
        #expect(TutorialStore.hasCompleted(defaults: defaults))
    }

    @Test func newUserStillSeesTutorial() {
        TutorialStore.skipForExistingUserOnce(isExistingUser: false, defaults: defaults)
        #expect(!TutorialStore.hasCompleted(defaults: defaults))
    }

    /// 新規ユーザーがスタートフロー完了後にガイド途中で終了しても、次回起動で既存扱いにならない。
    @Test func existingUserCheckRunsOnlyOnce() {
        TutorialStore.skipForExistingUserOnce(isExistingUser: false, defaults: defaults)
        TutorialStore.skipForExistingUserOnce(isExistingUser: true, defaults: defaults)
        #expect(!TutorialStore.hasCompleted(defaults: defaults))
    }
}
