//
//  RoomInviteURL.swift
//  beer_cheers
//
//  ルーム招待 URL の生成・パース（HTTPS 主 / beercheers スキーム補助）。
//

import Foundation

enum RoomInviteURL {
    /// HTTPS 招待 URL を作る。roomID は正規化後の値を想定。
    static func makeHTTPSURL(roomID: String) throws -> URL {
        let safe = try RoomID.normalize(roomID)
        guard var components = URLComponents(url: InviteLinkConfig.httpsOrigin, resolvingAgainstBaseURL: false) else {
            throw RoomRepositoryError.invalidRoomName
        }
        // path に生文字列を渡し、URLComponents 側で1回だけ percent-encode する
        // （先に encode すると % が %25 になり二重エンコードになる）
        components.path = "/\(InviteLinkConfig.joinPathPrefix)/\(safe)"
        guard let url = components.url else {
            throw RoomRepositoryError.invalidRoomName
        }
        return url
    }

    /// カスタムスキーム招待 URL（補助）。
    static func makeCustomSchemeURL(roomID: String) throws -> URL {
        let safe = try RoomID.normalize(roomID)
        var components = URLComponents()
        components.scheme = InviteLinkConfig.customScheme
        components.host = InviteLinkConfig.joinPathPrefix
        components.path = "/\(safe)"
        guard let url = components.url else {
            throw RoomRepositoryError.invalidRoomName
        }
        return url
    }

    /// 共有テキスト（HTTPS を主に載せる）。
    static func makeShareText(roomID: String) -> String {
        let safe = (try? RoomID.normalize(roomID)) ?? roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        let link: String
        if let url = try? makeHTTPSURL(roomID: safe) {
            link = url.absoluteString
        } else {
            link = safe
        }
        return "beercheers のルーム「\(safe)」に参加: \(link)"
    }

    /// HTTPS またはカスタムスキームから roomID を取り出す。失敗時は nil。
    static func parse(_ url: URL) -> String? {
        if let fromCustom = parseCustomScheme(url) {
            return fromCustom
        }
        return parseHTTPS(url)
    }

    // MARK: - Private

    private static func parseCustomScheme(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == InviteLinkConfig.customScheme
        else {
            return nil
        }

        // beercheers://join/<roomID>
        let host = url.host?.lowercased()
        guard host == InviteLinkConfig.joinPathPrefix else { return nil }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { return nil }
        let decoded = path.removingPercentEncoding ?? path
        return try? RoomID.normalize(decoded)
    }

    private static func parseHTTPS(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            return nil
        }

        let host = url.host?.lowercased()
        guard host == InviteLinkConfig.hostingHost.lowercased() else {
            return nil
        }

        // /join/<roomID>
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2,
              parts[0].lowercased() == InviteLinkConfig.joinPathPrefix
        else {
            return nil
        }
        let raw = parts.dropFirst().joined(separator: "/")
        let decoded = raw.removingPercentEncoding ?? raw
        return try? RoomID.normalize(decoded)
    }
}
