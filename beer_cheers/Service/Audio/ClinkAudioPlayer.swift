//
//  ClinkAudioPlayer.swift
//  beer_cheers
//
//  乾杯音（clink）の再生を担当する。
//  ・AVAudioSession の設定（mixWithOthers）
//  ・割り込み（電話/Siri など）でのポーズと復帰
//  ・mp3 / wav のいずれかをバンドルから解決して読み込む
//

import AVFoundation
import Foundation

@MainActor
final class ClinkAudioPlayer {
    private var player: AVAudioPlayer?
    private var didConfigureAudioSession = false
    private var interruptionObserver: NSObjectProtocol?

    init() {
        prepare()
    }


    /// AudioSession のアクティブ化と中断ハンドラの登録（衝撃検知開始時に呼ぶ）
    func activate() {
        ensureAudioSession()
        installInterruptionObserverIfNeeded()
    }

    /// AudioSession 中断ハンドラの解除（画面が消えるなどの停止時）
    func deactivate() {
        if let token = interruptionObserver {
            NotificationCenter.default.removeObserver(token)
            interruptionObserver = nil
        }
    }

    /// 乾杯時に呼ぶ。失敗時は内部で再ロードを試みる。
    func play() {
        ensureAudioSession()
        if player == nil {
            prepare()
        }
        guard let player else { return }
        player.volume = 1.0
        player.currentTime = 0
        if !player.play() {
            prepare()
            self.player?.currentTime = 0
            self.player?.play()
        }
    }

    private func ensureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if !didConfigureAudioSession {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                didConfigureAudioSession = true
            }
            try session.setActive(true, options: [])
        } catch {
            // 失敗しても他機能には波及させない。
        }
    }

    private func prepare() {
        guard let url = resolveBundledURL() else {
            player = nil
            return
        }
        let resolved: AVAudioPlayer?
        if let p = try? AVAudioPlayer(contentsOf: url) {
            resolved = p
        } else if let data = try? Data(contentsOf: url), let p = try? AVAudioPlayer(data: data) {
            resolved = p
        } else {
            resolved = nil
        }
        guard let resolved else {
            player = nil
            return
        }
        resolved.numberOfLoops = 0
        resolved.volume = 1.0
        resolved.prepareToPlay()
        player = resolved
    }

    private func resolveBundledURL() -> URL? {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "clink", ofType: "mp3") {
            return URL(fileURLWithPath: path)
        }
        if let url = bundle.url(forResource: "clink", withExtension: "mp3") { return url }
        if let url = bundle.url(forResource: "clink", withExtension: "mp3", subdirectory: "beer_cheers") {
            return url
        }
        if let hits = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            if let exact = hits.first(where: {
                $0.lastPathComponent.caseInsensitiveCompare("clink.mp3") == .orderedSame
            }) {
                return exact
            }
        }
        if let root = bundle.resourcePath {
            let fm = FileManager.default
            if let en = fm.enumerator(atPath: root) {
                for case let name as String in en {
                    guard name.lowercased().hasSuffix("clink.mp3") else { continue }
                    return URL(fileURLWithPath: (root as NSString).appendingPathComponent(name))
                }
            }
        }
        if let url = bundle.url(forResource: "clink", withExtension: "wav") { return url }
        return bundle.urls(forResourcesWithExtension: "wav", subdirectory: nil)?.first {
            $0.lastPathComponent.caseInsensitiveCompare("clink.wav") == .orderedSame
        }
    }

    private func installInterruptionObserverIfNeeded() {
        guard interruptionObserver == nil else { return }
        let session = AVAudioSession.sharedInstance()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            let optionsValue = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            Task { @MainActor in
                self?.handleInterruption(type: type, options: options)
            }
        }
    }

    private func handleInterruption(
        type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions
    ) {
        switch type {
        case .began:
            player?.pause()
        case .ended:
            if options.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true, options: [])
                prepare()
            }
        @unknown default:
            break
        }
    }
}
