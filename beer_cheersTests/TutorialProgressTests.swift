//
//  TutorialProgressTests.swift
//  beer_cheersTests
//

import Testing
@testable import beer_cheers

struct TutorialProgressTests {
    @Test func isInactiveUntilStarted() {
        let progress = TutorialProgress()
        #expect(!progress.isActive)
        #expect(progress.step == nil)
    }

    @Test func advancingPastLastStepEndsTutorial() {
        var progress = TutorialProgress()
        progress.start()
        #expect(progress.step == .cheers)

        progress.advance()
        #expect(progress.step == .watch)
        progress.advance()
        #expect(progress.step == .room)
        progress.advance()
        #expect(!progress.isActive)
    }

    @Test func cheersCountsAsPracticeOnlyDuringCheersStep() {
        var progress = TutorialProgress()
        progress.start()
        progress.advance()

        progress.recordLocalCheers()
        #expect(!progress.didPracticeCheers)
    }

    @Test func cheersDuringCheersStepIsRecorded() {
        var progress = TutorialProgress()
        progress.start()

        progress.recordLocalCheers()
        #expect(progress.didPracticeCheers)
    }

    @Test func cheersWhileInactiveIsIgnored() {
        var progress = TutorialProgress()
        progress.recordLocalCheers()
        #expect(!progress.didPracticeCheers)
    }

    @Test func restartingResetsPracticeState() {
        var progress = TutorialProgress()
        progress.start()
        progress.recordLocalCheers()
        progress.finish()

        progress.start()
        #expect(progress.step == .cheers)
        #expect(!progress.didPracticeCheers)
    }

    @Test func finishEndsFromAnyStep() {
        var progress = TutorialProgress()
        progress.start()
        progress.advance()

        progress.finish()
        #expect(!progress.isActive)
    }
}
