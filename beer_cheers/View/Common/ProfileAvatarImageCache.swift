//
//  ProfileAvatarImageCache.swift
//  beer_cheers
//
//  プロフィール画像のメモリキャッシュ（メンバー一覧の再表示コストを下げる）。
//

import Foundation
import UIKit

enum ProfileAvatarImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }

    static func store(_ image: UIImage, for urlString: String) {
        cache.setObject(image, forKey: urlString as NSString)
    }

    static func remove(for urlString: String) {
        cache.removeObject(forKey: urlString as NSString)
    }
}
