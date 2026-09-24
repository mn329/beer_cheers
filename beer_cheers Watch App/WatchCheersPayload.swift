//
//  WatchCheersPayload.swift
//  beer_cheers Watch App
//
//  Watch ↔ iPhone の WatchConnectivity ペイロード定義。
//  iPhone 側 CheersPhoneConnectivity のキーと一致させること。
//

import Foundation

enum WatchCheersPayload {
    static let actionKey = "action"
    static let cheersAction = "cheers"
    static let idKey = "id"

    static func makeCheersMessage() -> [String: Any] {
        [
            actionKey: cheersAction,
            idKey: UUID().uuidString,
        ]
    }
}
