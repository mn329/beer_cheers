//
//  RoomSection.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/05/27.
//

import SwiftUI

struct RoomSection: View {
    @Bindable var viewModel: AccountViewModel
    @State private var draftRoomID: String = ""
    @FocusState private var isFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14){
            SectionTitle(text:"ルーム", systemImage: "person.2.fill")
            Text("同じルームにいる端末で乾杯できます。")
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)
            HStack(spacing: 18){
                TextField("test_room", text: $draftRoomID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(GlassFieldBackground())
                    .foregroundStyle(AccountContentStyle.primary)
                Button(action: commit){
                    Text("接続")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.9))
                .foregroundStyle(.black)
            }
            
            HStack(spacing: 6){
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(AccountContentStyle.secondary)
                Text("現在: ")
                    .foregroundStyle(AccountContentStyle.secondary)
                Text(viewModel.roomID)
                    .foregroundStyle(AccountContentStyle.primary)
                    .fontWeight(.semibold)
            }
            .font(.footnote)
        }
        .padding(16)
        .background(GlassCardBackground())
        .onAppear{ draftRoomID = viewModel.roomID }
        .onChange(of: viewModel.roomID){ _, newValue in
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
    ZStack(){
        AppBackground()
        RoomSection(viewModel: AccountViewModel())
            .padding()
    }
}
