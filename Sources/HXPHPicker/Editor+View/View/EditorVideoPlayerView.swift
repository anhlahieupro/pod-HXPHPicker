//
//  EditorVideoPlayerView.swift
//  HXPHPicker
//
//  Created by Slience on 2022/11/12.
//

import UIKit
import AVKit

protocol EditorVideoPlayerViewDelegate: AnyObject {
    func playerView(_ playerView: EditorVideoPlayerView, didPlayAt time: CMTime)
    func playerView(_ playerView: EditorVideoPlayerView, didPauseAt time: CMTime)
    func playerView(readyForDisplay playerView: EditorVideoPlayerView)
}

class EditorVideoPlayerView: VideoPlayerView {
    weak var delegate: EditorVideoPlayerViewDelegate?
    var playbackTimeObserver: Any?
    var playStartTime: CMTime?
    var playEndTime: CMTime?
    var isPlaying: Bool = false
    var shouldPlay = true
    var readyForDisplayObservation: NSKeyValueObservation?
    var rateObservation: NSKeyValueObservation?
    var statusObservation: NSKeyValueObservation?
    var videoSize: CGSize = .zero
    
    var isLookOriginal: Bool = false
    var filterInfo: PhotoEditorFilterInfo?
    var filterParameters: [PhotoEditorFilterParameterInfo] = []
    lazy var coverImageView: UIImageView = {
        let imageView = UIImageView.init()
        return imageView
    }()
    
    convenience init(videoURL: URL) {
        self.init(avAsset: AVAsset(url: videoURL))
    }
    convenience init(avAsset: AVAsset) {
        self.init()
        self.avAsset = avAsset
        configAsset()
    }
    override init() {
        super.init()
        addSubview(coverImageView)
    }
    func configAsset(_ completion: ((Bool) -> Void)? = nil) {
        guard let avAsset = avAsset else {
            completion?(false)
            return
        }
        avAsset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            DispatchQueue.main.async {
                if avAsset.statusOfValue(forKey: "tracks", error: nil) != .loaded {
                    completion?(false)
                    return
                }
                self?.setupAsset(avAsset, completion: completion)
            }
        }
    }
    func setupAsset(_ avAsset: AVAsset, completion: ((Bool) -> Void)? = nil) {
        if let videoTrack = avAsset.tracks(withMediaType: .video).first {
            self.videoSize = videoTrack.naturalSize
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        let playerItem = AVPlayerItem(asset: avAsset)
        playerItem.videoComposition = videoComposition(avAsset)
        player.replaceCurrentItem(with: playerItem)
        playerLayer.player = player
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterPlayGround),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTimeNotification(notifi:)),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        rateObservation = player
            .observe(
                \.rate,
                options: [.new, .old]
            ) { [weak self] player, change in
                guard let self = self else { return }
                if player.rate == 0 && self.isPlaying {
                    self.pause()
                }
        }
        statusObservation = player
            .observe(
                \.status,
                options: [.new, .old]
            ) { player, change in
                switch player.status {
                case .readyToPlay:
                    completion?(true)
                case .failed:
                    completion?(false)
                case .unknown:
                    break
                @unknown default:
                    break
                }
        }
        readyForDisplayObservation = playerLayer
            .observe(
                \.isReadyForDisplay,
                options: [.new, .old]
            ) { [weak self] playerLayer, change in
                guard let self = self else { return }
                if playerLayer.isReadyForDisplay {
                    self.coverImageView.isHidden = true
                    self.play()
                    self.delegate?.playerView(readyForDisplay: self)
                }
        }
    }
    func videoComposition(_ avAsset: AVAsset) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition(
            asset: avAsset
        ) { [weak self] request in
            let source = request.sourceImage.clampedToExtent()
            guard let ciImage = self?.applyFilter(source) else {
                request.finish(
                    with: NSError(
                        domain: "videoComposition filter error：ciImage is nil",
                        code: 500,
                        userInfo: nil
                    )
                )
                return
            }
            request.finish(with: ciImage, context: nil)
        }
        videoComposition.renderScale = 1
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        return videoComposition
    }
    
    var beforEnterIsPlaying: Bool = false
    
    @objc func appDidEnterBackground() {
        beforEnterIsPlaying = isPlaying
        pause()
    }
    @objc  func appDidEnterPlayGround() {
        if beforEnterIsPlaying {
            play()
        }
    }
    @objc func playerItemDidPlayToEndTimeNotification(notifi: Notification) {
        resetPlay()
    }
    func seek(to time: CMTime, comletion: ((Bool) -> Void)? = nil) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { (isFinished) in
            comletion?(isFinished)
        }
    }
    func pause() {
        if isPlaying {
            if player.rate != 0 {
                player.pause()
            }
            isPlaying = false
            delegate?.playerView(self, didPauseAt: player.currentTime())
        }
    }
    func play() {
        if !isPlaying {
            player.play()
            isPlaying = true
            delegate?.playerView(self, didPlayAt: player.currentTime())
        }
    }
    func resetPlay(completion: ((CMTime) -> Void)? = nil) {
        isPlaying = false
        if let startTime = playStartTime {
            seek(to: startTime) { [weak self] isFinished in
                guard let self = self, isFinished else {
                    return
                }
                self.play()
                completion?(self.player.currentTime())
            }
        }else {
            seek(to: .zero) { [weak self] isFinished in
                guard let self = self, isFinished else {
                    return
                }
                self.play()
                completion?(self.player.currentTime())
            }
        }
    }
    func clear() {
        avAsset?.cancelLoading()
        NotificationCenter.default.removeObserver(self)
        statusObservation = nil
        rateObservation = nil
        readyForDisplayObservation = nil
        player.replaceCurrentItem(with: nil)
        playerLayer.player = nil
        avAsset = nil
        coverImageView.isHidden = false
        isPlaying = false
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        coverImageView.frame = bounds
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        clear()
    }
}

extension EditorVideoPlayerView {
    
    func applyFilter(_ source: CIImage) -> CIImage {
        if isLookOriginal {
            return source
        }
        guard let info = filterInfo else {
            return source
        }
        guard let ciImage = info.videoFilterHandler?(source, filterParameters) else {
            return source
        }
        return ciImage
    }
    
    func setFilter(
        _ info: PhotoEditorFilterInfo?,
        parameters: [PhotoEditorFilterParameterInfo]
    ) {
        filterInfo = info
        filterParameters = parameters
    }
}

