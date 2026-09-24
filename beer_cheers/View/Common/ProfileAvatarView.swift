//
//  ProfileAvatarView.swift
//  beer_cheers
//
//  プロフィール／メンバー用の円形アバター（URL 優先、なければ絵文字）。
//

import SwiftUI

struct ProfileAvatarView: View {
    var avatarURL: String?
    var avatarEmoji: String
    var size: CGFloat
    var emojiSize: CGFloat

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.45))

            content
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .contentShape(Circle())
        .id(avatarURL ?? "emoji-\(avatarEmoji)")
        .task(id: avatarURL) {
            await loadRemoteImageIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadedImage {
            Image(uiImage: loadedImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
        } else if let avatarURL, !avatarURL.isEmpty, !loadFailed {
            ProgressView()
                .tint(.black.opacity(0.5))
        } else {
            emojiFallback
        }
    }

    private var emojiFallback: some View {
        Text(avatarEmoji)
            .font(.system(size: emojiSize))
            .frame(width: size, height: size)
    }

    private func loadRemoteImageIfNeeded() async {
        loadedImage = nil
        loadFailed = false
        guard let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) else { return }

        if let cached = ProfileAvatarImageCache.image(for: avatarURL) {
            loadedImage = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                loadFailed = true
                return
            }
            guard let image = UIImage(data: data) else {
                loadFailed = true
                return
            }
            ProfileAvatarImageCache.store(image, for: avatarURL)
            loadedImage = image
        } catch {
            loadFailed = true
            #if DEBUG
                print("[Avatar] load failed: \(error.localizedDescription)")
            #endif
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ProfileAvatarView(avatarURL: nil, avatarEmoji: "🍺", size: 56, emojiSize: 28)
        ProfileAvatarView(
            avatarURL: "https://picsum.photos/200",
            avatarEmoji: "🍺",
            size: 56,
            emojiSize: 28
        )
    }
    .padding()
    .background(AppBackground())
}
