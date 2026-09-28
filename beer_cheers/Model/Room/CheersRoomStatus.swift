//
//  CheersRoomStatus.swift
//  beer_cheers
//
//  乾杯画面に出す「いまの乾杯がどこへ届くか」。
//

import Foundation

struct CheersRoomStatus: Equatable {
    /// 共有ルームの名前。ゲストルーム（自分ひとり）なら nil。
    let roomName: String?
    /// メンバーの読み込み中は nil。
    let memberCount: Int?

    init(roomID: String, memberCount: Int?) {
        roomName = RoomSessionStore.isGuestRoomID(roomID) ? nil : roomID
        self.memberCount = memberCount
    }

    var isAlone: Bool { roomName == nil }

    var title: String {
        guard let roomName else { return "ひとりで練習中" }
        guard let memberCount else { return roomName }
        return "\(roomName)・\(memberCount)人"
    }

    var subtitle: String? {
        isAlone ? "ルームに入ると仲間に届きます" : nil
    }

    static func senderCaption(nickname: String) -> String {
        "\(nickname)から乾杯！"
    }
}
