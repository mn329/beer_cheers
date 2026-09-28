//
//  TutorialStep.swift
//  beer_cheers
//
//  使い方ガイドのステップ順と文言。表示位置や色は TutorialCoachOverlay が決める。
//

import Foundation

struct TutorialBullet: Hashable {
    let systemImage: String
    let text: String
}

struct TutorialScreenshot: Hashable {
    /// Asset Catalog 名
    let assetName: String
    let accessibilityLabel: String
}

enum TutorialStep: Int, CaseIterable {
    case cheers
    case watch
    case room

    var next: TutorialStep? {
        TutorialStep(rawValue: rawValue + 1)
    }

    var progressText: String {
        "\(rawValue + 1) / \(Self.allCases.count)"
    }

    func emoji(didPracticeCheers: Bool) -> String {
        switch self {
        case .cheers: didPracticeCheers ? "🎉" : "🍻"
        case .watch: "⌚️"
        case .room: "👥"
        }
    }

    func title(didPracticeCheers: Bool) -> String {
        switch self {
        case .cheers: didPracticeCheers ? "ナイス乾杯！" : "iPhone を振って乾杯してみよう"
        case .watch: "Apple Watch でも乾杯"
        case .room: "ルームで仲間とつながる"
        }
    }

    /// 実画面を iPhone 上に出せないステップだけ、スクリーンショットで補う。
    var screenshot: TutorialScreenshot? {
        switch self {
        case .watch: TutorialScreenshot(assetName: "TutorialWatch", accessibilityLabel: "Apple Watch の乾杯画面")
        case .cheers, .room: nil
        }
    }

    var bullets: [TutorialBullet] {
        switch self {
        case .cheers:
            []
        case .watch:
            [
                TutorialBullet(systemImage: "arrow.down.app", text: "Watch に無ければ、iPhone の Watch アプリ →「利用可能な App」からインストール"),
                TutorialBullet(systemImage: "iphone", text: "iPhone の beercheers も起動しておく"),
                TutorialBullet(systemImage: "applewatch.radiowaves.left.and.right", text: "腕を振る、またはビールをタップして乾杯"),
                TutorialBullet(systemImage: "pause.circle", text: "使わないときは「検知オフ」で止められる"),
            ]
        case .room:
            [
                TutorialBullet(systemImage: "plus.circle", text: "この画面でルーム名を決めて「作成する」"),
                TutorialBullet(systemImage: "square.and.arrow.up", text: "入室後に出る招待リンクをコピー／共有して仲間に送る"),
                TutorialBullet(systemImage: "person.2.fill", text: "仲間はリンクを開くか、「参加」でルーム名を入れて入室"),
            ]
        }
    }

    // MARK: - 乾杯ステップ

    static let practiceNote = "練習中の乾杯はルームに送信されません。"

    static func practiceMessage(isMotionAvailable: Bool, didPracticeCheers: Bool) -> String {
        if didPracticeCheers {
            return "ルームに入れば、この音と振動が仲間の端末にも届きます。"
        }
        if !isMotionAvailable {
            return "この端末ではモーションセンサーが使えません。実機の iPhone で試してみてください。"
        }
        return "グラスを合わせるように、iPhone を勢いよく振って「カンッ」と止めます。"
    }

    /// 振れる端末でまだ乾杯していない間は、先へ進むより練習を促す。
    static func isWaitingForPractice(isMotionAvailable: Bool, didPracticeCheers: Bool) -> Bool {
        isMotionAvailable && !didPracticeCheers
    }
}
