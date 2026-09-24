//
//  WatchCheersView.swift
//  beer_cheers Watch App
//
//  振る／タップで乾杯。検知トグルでスリープ継続と通信を止められる。
//

import SwiftUI

struct WatchCheersView: View {
    @State private var viewModel = WatchCheersViewModel()

    var body: some View {
        ZStack {
            background
            content
        }
        .task {
            viewModel.bootstrap()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: viewModel.isSensingEnabled ? Self.activeColors : Self.pausedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 8) {
            cheersHitArea
            sensingToggle
        }
    }

    private var cheersHitArea: some View {
        VStack(spacing: 8) {
            Text("🍺")
                .font(.system(size: 48))
                .scaleEffect(viewModel.mugScale)
                .rotationEffect(.degrees(viewModel.mugRotation))
                .offset(y: viewModel.mugOffsetY)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
                .opacity(viewModel.isSensingEnabled ? 1 : 0.45)

            Text(viewModel.captionVisible ? "CHEERS!!" : viewModel.idleCaption)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .opacity(viewModel.captionVisible ? 1 : 0.85)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.cheers()
        }
    }

    private var sensingToggle: some View {
        Button {
            viewModel.toggleSensing()
        } label: {
            Text(viewModel.sensingToggleTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        viewModel.isSensingEnabled
                            ? Color.black.opacity(0.35)
                            : Color.green.opacity(0.55)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private static let activeColors: [Color] = [
        Color(red: 0.98, green: 0.72, blue: 0.18),
        Color(red: 0.92, green: 0.45, blue: 0.12),
        Color(red: 0.55, green: 0.12, blue: 0.08),
    ]

    private static let pausedColors: [Color] = [
        Color(red: 0.25, green: 0.25, blue: 0.28),
        Color(red: 0.12, green: 0.12, blue: 0.14),
    ]
}

#Preview {
    WatchCheersView()
}
