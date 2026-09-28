//
//  TutorialStepTests.swift
//  beer_cheersTests
//

import Testing
@testable import beer_cheers

struct TutorialStepTests {
    @Test func stepsProceedFromCheersToWatchToRoomThenEnd() {
        #expect(TutorialStep.cheers.next == .watch)
        #expect(TutorialStep.watch.next == .room)
        #expect(TutorialStep.room.next == nil)
    }

    @Test func progressTextShowsCurrentPositionOutOfTotal() {
        #expect(TutorialStep.cheers.progressText == "1 / 3")
        #expect(TutorialStep.room.progressText == "3 / 3")
    }

    @Test(arguments: [
        (isMotionAvailable: true, didPracticeCheers: false, expected: true),
        (isMotionAvailable: true, didPracticeCheers: true, expected: false),
        (isMotionAvailable: false, didPracticeCheers: false, expected: false),
    ])
    func waitsForPracticeOnlyWhenDeviceCanDetectMotionAndNotYetPracticed(
        isMotionAvailable: Bool,
        didPracticeCheers: Bool,
        expected: Bool
    ) {
        let result = TutorialStep.isWaitingForPractice(
            isMotionAvailable: isMotionAvailable,
            didPracticeCheers: didPracticeCheers
        )
        #expect(result == expected)
    }

    @Test func practiceMessagePrefersSuccessOverMissingSensor() {
        let success = TutorialStep.practiceMessage(isMotionAvailable: false, didPracticeCheers: true)
        let noSensor = TutorialStep.practiceMessage(isMotionAvailable: false, didPracticeCheers: false)
        #expect(success != noSensor)
        #expect(noSensor.contains("モーションセンサー"))
    }

    @Test func onlyWatchStepUsesScreenshot() {
        #expect(TutorialStep.watch.screenshot?.assetName == "TutorialWatch")
        #expect(TutorialStep.cheers.screenshot == nil)
        #expect(TutorialStep.room.screenshot == nil)
    }
}
