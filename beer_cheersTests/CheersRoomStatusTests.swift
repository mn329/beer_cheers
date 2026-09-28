//
//  CheersRoomStatusTests.swift
//  beer_cheersTests
//

import Testing
@testable import beer_cheers

struct CheersRoomStatusTests {
    @Test func guestRoomIsShownAsPracticingAlone() {
        let status = CheersRoomStatus(roomID: RoomSessionStore.makeGuestRoomID(), memberCount: 1)

        #expect(status.isAlone)
        #expect(status.title == "ひとりで練習中")
        #expect(status.subtitle == "ルームに入ると仲間に届きます")
    }

    @Test func sharedRoomShowsNameAndMemberCount() {
        let status = CheersRoomStatus(roomID: "weekend", memberCount: 3)

        #expect(!status.isAlone)
        #expect(status.title == "weekend・3人")
        #expect(status.subtitle == nil)
    }

    @Test func memberCountIsHiddenWhileLoading() {
        #expect(CheersRoomStatus(roomID: "weekend", memberCount: nil).title == "weekend")
    }
}
