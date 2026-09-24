//
//  ProfileAvatarRepository.swift
//  beer_cheers
//
//  プロフィール画像を Firebase Storage にアップロードする Repository。
//

import FirebaseStorage
import Foundation
import UIKit

enum ProfileAvatarRepositoryError: Error {
    case notSignedIn
    case imageEncodingFailed
    case firebaseNotConfigured
}

protocol ProfileAvatarRepositorying: Sendable {
    func uploadAvatarJPEGData(_ data: Data, uid: String) async throws -> URL
    func deleteAvatarIfExists(uid: String) async
}

struct FirebaseProfileAvatarRepository: ProfileAvatarRepositorying {
    func uploadAvatarJPEGData(_ data: Data, uid: String) async throws -> URL {
        try await ProfileAvatarRepository.uploadAvatarJPEGData(data, uid: uid)
    }

    func deleteAvatarIfExists(uid: String) async {
        await ProfileAvatarRepository.deleteAvatarIfExists(uid: uid)
    }
}

enum ProfileAvatarRepository {
    /// JPEG を `avatars/{uid}.jpg` に上げ、ダウンロード URL を返す。
    static func uploadAvatarJPEGData(_ data: Data, uid: String) async throws -> URL {
        guard FirebaseBootstrap.isConfigured else {
            throw ProfileAvatarRepositoryError.firebaseNotConfigured
        }
        guard !uid.isEmpty else {
            throw ProfileAvatarRepositoryError.notSignedIn
        }

        let ref = Storage.storage().reference().child("avatars/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        ProfileAvatarImageCache.remove(for: url.absoluteString)
        // 同じ Storage パスでも URL クエリが変わることがあるため、uid キーでも消す必要はない
        return url
    }

    /// プロフィール設定キャンセル時など、自分のアバターを消す。
    static func deleteAvatarIfExists(uid: String) async {
        guard FirebaseBootstrap.isConfigured, !uid.isEmpty else { return }
        let ref = Storage.storage().reference().child("avatars/\(uid).jpg")
        do {
            try await ref.delete()
        } catch {
            #if DEBUG
                print("[Profile] avatar delete skipped: \(error.localizedDescription)")
            #endif
        }
    }

    static func jpegData(from image: UIImage, maxDimension: CGFloat = 512, quality: CGFloat = 0.82) -> Data? {
        let scaled = scaledImage(image, maxDimension: maxDimension)
        return scaled.jpegData(compressionQuality: quality)
    }

    private static func scaledImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

typealias ProfileAvatarService = ProfileAvatarRepository
typealias ProfileAvatarServiceError = ProfileAvatarRepositoryError
