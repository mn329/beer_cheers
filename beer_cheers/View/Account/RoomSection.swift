//
//  RoomSection.swift
//  beer_cheers
//
//  Realtime DB のルーム ID を切り替えるセクション。
//  保存時に AccountViewModel 経由で AirCheersViewModel に再接続を通知する。
//

import SwiftUI

struct RoomSection: View {
    @Bindable var viewModel: AccountViewModel

    @State private var draftRoomID: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "ルーム", systemImage: "person.2.fill")

            Text("同じルームに居る端末同士で乾杯のタイミングが同期されます。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 10) {
                TextField("test_room", text: $draftRoomID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(GlassFieldBackground())
                    .foregroundStyle(.white)

                Button(action: commit) {
                    Text("接続")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.9))
                .foregroundStyle(.black)
            }

            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.white.opacity(0.85))
                Text("現在: ")
                    .foregroundStyle(.white.opacity(0.8))
                Text(viewModel.roomID)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
            .font(.footnote)
        }
        .padding(16)
        .background(GlassCardBackground())
        .onAppear { draftRoomID = viewModel.roomID }
        .onChange(of: viewModel.roomID) { _, newValue in
            // 別画面から保存された場合の同期
            if draftRoomID != newValue { draftRoomID = newValue }
        }
    }

    private func commit() {
        viewModel.roomID = draftRoomID
        viewModel.commitRoomID()
        isFocused = false
    }
}

#Preview {
    ZStack {
        AppBackground()
        RoomSection(viewModel: AccountViewModel())
            .padding()
    }
}
