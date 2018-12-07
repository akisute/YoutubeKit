//
//  YTSwiftyPlayer.swift
//  YTSwiftyPlayer
//
//  Created by Ryo Ishikawa on 12/30/2017
//  Copyright © 2017 Ryo Ishikawa. All rights reserved.
//
import UIKit
import WebKit

/**
 * `YTSwiftyPlayer` is a subclass of `WKWebView` that support fully Youtube IFrame API.
 * It can be instantiated only programmatically.
 * - note: This class is not support interface builder due to use `WKWebView`.
 * For more information: [https://developer.apple.com/documentation/webkit/wkwebview](https://developer.apple.com/documentation/webkit/wkwebview)
 */
public class YTSwiftyPlayer: WKWebView {
    
    public weak var delegate: YTSwiftyPlayerDelegate?
    
    /**
     Automatically plays the video programmatically at the moment of the `onReady` event.
     This property is provided because the WebKit (or Safari) in iOS has a strict restriction for autoplaying videos using the HTML5 feature,
     that is, a video must be muted to be autoplayed. See https://developers.google.com/web/updates/2016/07/autoplay for more info.
     By using this property:
     - You can reliably autoplay videos.
     - You can autoplay videos without muting the player.
     Note that this property tries to play the video at `onReady`. If you do not specify the `videoId` before `loadPlayer()`,
     this property can do anything at all. In that case, call `playVideo()` manually.
     */
    public var autoplayOnReady: Bool = false
    
    /**
     Automatically plays the video programmatically at the moment of the `onReady` event.
     This property is provided because the YouTube iframe API does not have any means to load the `muted` player.
     This causes multiple problems, such as:
     - You need to call mute() manually if you want to provide a muted video, which is bothering.
     - `autoplay` playerVar does not work because a video must be muted to be autoplayed by HTML5 feature in iOS: (https://developers.google.com/web/updates/2016/07/autoplay)
     This property also guarantees to mute the player before the `autoplayOnReady` property kicks in.
     */
    public var automuteOnReady: Bool = false
    
    /// `true` when the player is loaded and ready to play videos and evaluate JS requests, such as `mute()`.
    public private(set) var isPlayerReady = false
    
    public private(set) var isMuted = false
    
    public private(set) var playbackRate: Double = 1.0
    
    public private(set) var availablePlaybackRates: [Double] = [1]
    
    public private(set) var availableQualityLevels: [YTSwiftyVideoQuality] = []
    
    public private(set) var bufferedVideoRate: Double = 0
    
    public private(set) var currentPlaylist: [String] = []
    
    public private(set) var currentPlaylistIndex: Int = 0
    
    public private(set) var currentVideoURL: String?
    
    public private(set) var currentVideoEmbedCode: String?
    
    public private(set) var playerState: YTSwiftyPlayerState = .unstarted
    
    public private(set) var playerQuality: YTSwiftyVideoQuality = .unknown
    
    public private(set) var duration: Double?
    
    public private(set) var currentTime: Double = 0.0
    
    public var playerVars: [String: AnyObject] = [:]
    
    private let callbackHandlers: [YTSwiftyPlayerEvent] = [
        .onYoutubeIframeAPIReady,
        .onYouTubeIframeAPIFailedToLoad,
        .onReady,
        .onStateChange,
        .onQualityChange,
        .onPlaybackRateChange,
        .onApiChange,
        .onError,
        .onUpdateCurrentTime
    ]
    
    private static var defaultConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        return config
    }
    
    public init(frame: CGRect, playerVars: [String: AnyObject], configuration: WKWebViewConfiguration? = nil) {
        let config = configuration ?? YTSwiftyPlayer.defaultConfiguration
        // `mediaTypesRequiringUserActionForPlayback` must be empty in order to play videos properly without user interactions,
        // So the value is overwritten here no matter what.
        config.mediaTypesRequiringUserActionForPlayback = []
        
        super.init(frame: frame, configuration: config)
        
        callbackHandlers.forEach {
            config.userContentController.add(self, name: $0.rawValue)
        }
        
        commonInit()
        
        self.playerVars = playerVars
    }
    
    public init(frame: CGRect, parameters: [VideoEmbedParameter], configuration: WKWebViewConfiguration? = nil) {
        let config = configuration ?? YTSwiftyPlayer.defaultConfiguration
        // `mediaTypesRequiringUserActionForPlayback` must be empty in order to play videos properly without user interactions,
        // So the value is overwritten here no matter what.
        config.mediaTypesRequiringUserActionForPlayback = []
        
        super.init(frame: frame, configuration: config)
        
        callbackHandlers.forEach {
            config.userContentController.add(self, name: $0.rawValue)
        }
        
        commonInit()
        
        self.setPlayerParameters(parameters)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setPlayerParameters(_ parameters: [VideoEmbedParameter]) {
        var vars: [String: AnyObject] = [:]
        parameters.forEach {
            let property = $0.property
            vars[property.key] = property.value
        }
        self.playerVars = vars
    }
    
    public func playVideo() {
        evaluatePlayerCommand("playVideo()")
    }
    
    public func stopVideo() {
        evaluatePlayerCommand("stopVideo()")
    }
    
    public func seek(to seconds: Int, allowSeekAhead: Bool) {
        evaluatePlayerCommand("seekTo(\(seconds),\(allowSeekAhead ? 1 : 0))")
    }
    
    public func pauseVideo() {
        evaluatePlayerCommand("pauseVideo()")
    }
    
    public func clearVideo() {
        evaluatePlayerCommand("clearVideo()")
    }
    
    public func mute() {
        evaluatePlayerCommand("mute()") { [weak self] _, error in
            if let error = error, !YTSwiftyPlayer.isVoidReturn(error: error) {
                return
            }
            self?.isMuted = true
        }
    }
    
    public func unMute() {
        evaluatePlayerCommand("unMute()") { [weak self] _, error in
            if let error = error, !YTSwiftyPlayer.isVoidReturn(error: error) {
                return
            }
            self?.isMuted = false
        }
    }
    
    public func previousVideo() {
        evaluatePlayerCommand("previousVideo()")
    }
    
    public func nextVideo() {
        evaluatePlayerCommand("nextVideo()")
    }
    
    public func playVideo(at index: Int) {
        evaluatePlayerCommand("playVideoAt(\(index))")
    }
    
    public func setPlayerSize(width: Int, height: Int) {
        evaluatePlayerCommand("setSize(\(width),\(height))")
    }
    
    public func setPlaybackRate(_ suggestedRate: Double) {
        evaluatePlayerCommand("setPlaybackRate(\(suggestedRate))")
    }
    
    public func setPlaybackQuality(_ suggestedQuality: YTSwiftyVideoQuality) {
        evaluatePlayerCommand("setPlaybackQuality(\(suggestedQuality.rawValue))")
    }
    
    public func setLoop(_ loopPlaylists: Bool) {
        evaluatePlayerCommand("setLoop(\(loopPlaylists))")
    }
    
    public func setShuffle(_ shufflePlaylist: Bool) {
        evaluatePlayerCommand("setShuffle(\(shufflePlaylist))")
    }
    
    public func cueVideo(videoID: String, startSeconds: Int = 0, suggestedQuality: YTSwiftyVideoQuality = .large) {
        evaluatePlayerCommand("cueVideoById('\(videoID)',\(startSeconds),'\(suggestedQuality.rawValue)')")
    }
    
    public func loadVideo(videoID: String, startSeconds: Int = 0, suggestedQuality: YTSwiftyVideoQuality = .large) {
        evaluatePlayerCommand("loadVideoById('\(videoID)',\(startSeconds),'\(suggestedQuality.rawValue)')")
    }
    
    public func cueVideo(contentURL: String, startSeconds: Int = 0, suggestedQuality: YTSwiftyVideoQuality = .large) {
        evaluatePlayerCommand("cueVideoByUrl('\(contentURL)',\(startSeconds),'\(suggestedQuality.rawValue)')")
    }
    
    public func loadVideo(contentURL: String, startSeconds: Int = 0, suggestedQuality: YTSwiftyVideoQuality = .large) {
        evaluatePlayerCommand("loadVideoByUrl('\(contentURL)',\(startSeconds),'\(suggestedQuality.rawValue)')")
    }
    
    public func cuePlaylist(playlist: [String], startIndex: Int = 0, startSeconds: Int = 0, suggestedQuality: YTSwiftyVideoQuality = .large) {
        evaluatePlayerCommand("cuePlaylist('\(playlist.joined(separator: ","))',\(startIndex),\(startSeconds),'\(suggestedQuality.rawValue)')")
    }
    
    public func loadPlaylist(playlist: [String], startIndex: Int = 0, startSeconds: Int = 0, suggestedQuality: YTSwiftyVideoQuality = .large) {
        evaluatePlayerCommand("loadPlaylist('\(playlist.joined(separator: ","))',\(startIndex),\(startSeconds),'\(suggestedQuality.rawValue)')")
    }
    
    public func loadPlaylist(withVideoIDs ids: [String]) {
        evaluatePlayerCommand("loadPlaylist('\(ids.joined(separator: ","))')")
    }
    
    public func loadPlayer() {
        let events: [String: AnyObject] = {
            var registerEvents: [String: AnyObject] = [:]
            callbackHandlers.forEach {
                registerEvents[$0.rawValue] = $0.rawValue as AnyObject
            }
            return  registerEvents
        }()
        
        var parameters = [
            "width": "100%" as AnyObject,
            "height": "100%" as AnyObject,
            "events": events as AnyObject,
            "playerVars": playerVars as AnyObject,
            ]
        
        if let videoID = playerVars["videoId"] {
            parameters["videoId"] = videoID
        }
        
        guard let json = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            fatalError("JSON serialization of the YouTube iframe API parameters failed. It may be caused by the malformed `playerVars` property: \(playerVars)")
        }
        guard let jsonString = String(data: json, encoding: String.Encoding.utf8) else {
            fatalError("JSON stringify of the YouTube iframe API parameters failed. This may happen when `playerVars` contains non-UTF8 characters: \(playerVars)")
        }
        let html = YTSwiftyPlayerHTML.htmlString(playerArgs: jsonString)
        let baseUrl = URL(string: "https://www.youtube.com")!
        loadHTMLString(html, baseURL: baseUrl)
    }
    
    // MARK: - Private Methods
    
    private func commonInit() {
        backgroundColor = .clear
        scrollView.bounces = false
        scrollView.isScrollEnabled = false
        isUserInteractionEnabled = true
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func evaluatePlayerCommand(_ commandName: String, callbackHandler: ((Any?, Error?) -> (Void))? = nil) {
        let command = "player.\(commandName);"
        evaluateJavaScript(command, completionHandler: callbackHandler)
    }
    
    /**
     Returns `true` if the given `error` is caused by evaluating the JS function which returns `void`.
     This is because the current WebKit2 implementation throws `WKErrorJavaScriptResultTypeIsUnsupported` of `WKErrorDomain`
     when the serialization result of the returned value of the evaluated JS function is `nil`.
     And the `void`, which means `undefined` in the JS, cannot be serialized and returns `nil`, causing this error.
     https://opensource.apple.com/source/WebKit2/WebKit2-7601.1.46.9/UIProcess/API/Cocoa/WKWebView.mm.auto.html
     
     It's just absolutely bullshit. Why returns error just calling a `void` function...?
     */
    private static func isVoidReturn(error: Error) -> Bool {
        if let wkError = error as? WKError {
            return wkError.errorCode == WKError.Code.javaScriptResultTypeIsUnsupported.rawValue
        } else {
            let nsError = error as NSError
            return nsError.domain == WKErrorDomain && nsError.code == WKError.Code.javaScriptResultTypeIsUnsupported.rawValue
        }
    }
}

extension YTSwiftyPlayer: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = YTSwiftyPlayerEvent(rawValue: message.name) else { return }
        switch event {
        case .onReady:
            isPlayerReady = true
            handleAutoplayAndAutomute()
            updateInfo()
            delegate?.playerReady(self)
        case .onStateChange:
            updateState(message.body as? Int)
            let isLoop = playerVars["loop"] as? String == "1"
            if playerState == .ended && isLoop {
                playVideo()
            }
            delegate?.player(self, didChangeState: playerState)
        case .onQualityChange:
            updateQuality(message.body as? String)
            delegate?.player(self, didChangeQuality: playerQuality)
        case .onError:
            if let message = message.body as? Int,
                let error = YTSwiftyPlayerError(rawValue: message) {
                delegate?.player(self, didReceiveError: error)
            }
        case .onUpdateCurrentTime:
            updateInfo()
            if let currentTime = message.body as? Double {
                self.currentTime = currentTime
                delegate?.player(self, didUpdateCurrentTime: currentTime)
            }
        case .onPlaybackRateChange:
            if let playbackRate = message.body as? Double {
                delegate?.player(self, didChangePlaybackRate: playbackRate)
            }
        case .onApiChange:
            delegate?.apiDidChange(self)
        case .onYoutubeIframeAPIReady:
            delegate?.youtubeIframeAPIReady(self)
        case .onYouTubeIframeAPIFailedToLoad:
            delegate?.youtubeIframeAPIFailedToLoad(self)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleAutoplayAndAutomute() {
        switch (autoplayOnReady, automuteOnReady) {
        case (true, true):
            // automute first, then autoplay
            evaluatePlayerCommand("mute()") { [weak self] _, error in
                guard let me = self else { return }
                if let error = error, !YTSwiftyPlayer.isVoidReturn(error: error) {
                    return
                }
                me.isMuted = true
                me.playVideo()
            }
        case (true, false):
            // autoplay only
            playVideo()
        case (false, true):
            // automute only
            mute()
        default: break
        }
    }
    
    private func updateInfo() {
        updateMute()
        updatePlaybackRate()
        updateAvailableQualityLevels()
        updateCurrentPlaylist()
        updateCurrentVideoURL()
        updateCurrentVideoEmbedCode()
        updatePlaylistIndex()
        updateDuration()
        updateVideoLoadedFraction()
    }
    
    private func updateMute() {
        evaluatePlayerCommand("isMuted()") { [weak self] result, _ in
            guard let me = self,
                let isMuted = result as? Bool else { return }
            me.isMuted = isMuted
        }
    }
    
    private func updatePlaybackRate() {
        evaluatePlayerCommand("getPlaybackRate()") { [weak self] result, _ in
            guard let me = self,
                let playbackRate = result as? Double else { return }
            me.playbackRate = playbackRate
        }
    }
    
    private func updateVideoLoadedFraction() {
        evaluatePlayerCommand("getVideoLoadedFraction()") { [weak self] result, _ in
            guard let me = self,
                let bufferedVideoRate = result as? Double else { return }
            me.bufferedVideoRate = bufferedVideoRate
        }
    }
    
    private func updateAvailableQualityLevels() {
        evaluatePlayerCommand("getAvailableQualityLevels()") { [weak self] result, _ in
            guard let me = self,
                let availableQualityLevels = result as? [String] else { return }
            me.availableQualityLevels = availableQualityLevels
                .compactMap { YTSwiftyVideoQuality(rawValue: $0) }
        }
    }
    
    private func updateCurrentVideoURL() {
        evaluatePlayerCommand("getVideoUrl()") { [weak self] result, _ in
            guard let me = self,
                let url = result as? String else { return }
            me.currentVideoURL = url
        }
    }
    
    private func updateCurrentVideoEmbedCode() {
        evaluatePlayerCommand("getVideoEmbedCode()") { [weak self] result, _ in
            guard let me = self,
                let embedCode = result as? String else { return }
            me.currentVideoEmbedCode = embedCode
        }
    }
    
    private func updateCurrentPlaylist() {
        evaluatePlayerCommand("getPlaylist()") { [weak self] result, _ in
            guard let me = self,
                let playlist = result as? [String] else { return }
            me.currentPlaylist = playlist
        }
    }
    
    private func updatePlaylistIndex() {
        evaluatePlayerCommand("getPlaylistIndex()") { [weak self] result, _ in
            guard let me = self,
                let index = result as? Int else { return }
            me.currentPlaylistIndex = index
        }
    }
    
    private func updateDuration() {
        evaluatePlayerCommand("getDuration()") { [weak self] result, _ in
            guard let me = self,
                let duration = result as? Double else { return }
            me.duration = duration
        }
    }
    
    private func updateState(_ message: Int?) {
        var state: YTSwiftyPlayerState = .unstarted
        if let message = message,
            let newState = YTSwiftyPlayerState(rawValue: message) {
            state = newState
        }
        playerState = state
    }
    
    private func updateQuality(_ message: String?) {
        var quality: YTSwiftyVideoQuality = .unknown
        if let message = message,
            let newQuality = YTSwiftyVideoQuality(rawValue: message) {
            quality = newQuality
        }
        playerQuality = quality
    }
}
