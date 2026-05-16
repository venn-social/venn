import AVFoundation
import SwiftUI
import UIKit

/// Thin SwiftUI wrapper around `AVPlayerLayer` for bundled, silent brand
/// videos. Reused by launch and in-app loading so playback behavior stays
/// consistent.
struct VennVideoPlayer: UIViewRepresentable {
    let resource: VennVideoResource
    var loops = false
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var backgroundColor: UIColor = .black
    var onCompletion: (@MainActor () -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> VennVideoContainerView {
        let view = VennVideoContainerView()
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: VennVideoContainerView, context: Context) {
        if uiView.resource != resource || uiView.loops != loops {
            configure(uiView, coordinator: context.coordinator)
        } else {
            uiView.backgroundColor = backgroundColor
            uiView.videoGravity = videoGravity
            uiView.player?.play()
        }
    }

    static func dismantleUIView(_ uiView: VennVideoContainerView, coordinator: Coordinator) {
        coordinator.looper = nil
        coordinator.removeEndObserver()
        uiView.player?.pause()
        uiView.player = nil
    }

    private func configure(_ view: VennVideoContainerView, coordinator: Coordinator) {
        view.backgroundColor = backgroundColor
        view.videoGravity = videoGravity
        view.resource = resource
        view.loops = loops
        coordinator.looper = nil
        coordinator.removeEndObserver()

        guard let url = resource.url else {
            view.player = nil
            return
        }

        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = loops ? .none : .pause

        if loops {
            let item = AVPlayerItem(url: url)
            coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            let item = AVPlayerItem(url: url)
            if let onCompletion {
                coordinator.endObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { _ in
                    Task { @MainActor in onCompletion() }
                }
            }
            player.insert(item, after: nil)
        }

        view.player = player
        player.play()
    }

    @MainActor
    final class Coordinator {
        var looper: AVPlayerLooper?
        var endObserver: NSObjectProtocol?

        func removeEndObserver() {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
        }
    }
}

@MainActor
final class VennVideoContainerView: UIView {
    private let playerLayer = AVPlayerLayer()

    var resource: VennVideoResource?
    var loops = false
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }

    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
