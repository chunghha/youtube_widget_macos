// lib/providers/player_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_widget_macos/services/keyboard_service.dart';
import 'package:youtube_widget_macos/services/shared_preferences_service.dart';
import 'package:youtube_widget_macos/services/youtube_webview_manager.dart';
import 'package:youtube_widget_macos/services/window_service.dart';
import 'package:youtube_widget_macos/utils/youtube_url_parser.dart';

// 1. Immutable State Class
class YouTubePlayerState {
  final bool isLoading;
  final String? errorMessage;
  final bool isPlaying;
  final bool isPlayerReady;
  final double currentPosition;
  final double totalDuration;
  final double volume;
  final bool isMuted;
  final bool isLiveStream;
  final bool showControls;
  final bool showMediaControls;
  final WebViewController? webViewController;
  final bool isFullScreen;

  YouTubePlayerState({
    required this.isLoading,
    this.errorMessage,
    required this.isPlaying,
    required this.isPlayerReady,
    required this.currentPosition,
    required this.totalDuration,
    required this.volume,
    required this.isMuted,
    required this.isLiveStream,
    required this.showControls,
    required this.showMediaControls,
    this.webViewController,
    required this.isFullScreen,
  });

  YouTubePlayerState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isPlaying,
    bool? isPlayerReady,
    double? currentPosition,
    double? totalDuration,
    double? volume,
    bool? isMuted,
    bool? isLiveStream,
    bool? showControls,
    bool? showMediaControls,
    WebViewController? webViewController,
    bool? isFullScreen,
  }) {
    return YouTubePlayerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isPlaying: isPlaying ?? this.isPlaying,
      isPlayerReady: isPlayerReady ?? this.isPlayerReady,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isLiveStream: isLiveStream ?? this.isLiveStream,
      showControls: showControls ?? this.showControls,
      showMediaControls: showMediaControls ?? this.showMediaControls,
      webViewController: webViewController ?? this.webViewController,
      isFullScreen: isFullScreen ?? this.isFullScreen,
    );
  }
}

// 2. StateNotifier for Player Logic
class YouTubePlayerNotifier extends StateNotifier<YouTubePlayerState> {
  YouTubeWebViewManager _webViewManager;
  final Ref _ref;

  YouTubePlayerNotifier(this._ref)
      : _webViewManager = YouTubeWebViewManager(),
        super(YouTubePlayerState(
          isLoading: false,
          isPlaying: false,
          isPlayerReady: false,
          currentPosition: 0.0,
          totalDuration: 0.0,
          volume: 100.0,
          isMuted: false,
          isLiveStream: false,
          showControls: true,
          showMediaControls: false,
          webViewController: null,
          isFullScreen: false,
        )) {
    _attachListeners();
    _loadInitialSettings();
  }

  void _attachListeners() {
    _webViewManager.isLoadingNotifier.addListener(_updateFromManager);
    _webViewManager.errorMessageNotifier.addListener(_updateFromManager);
    _webViewManager.isPlayingNotifier.addListener(_updateFromManager);
    _webViewManager.isPlayerReadyNotifier.addListener(_updateFromManager);
    _webViewManager.currentPositionNotifier.addListener(_updateFromManager);
    _webViewManager.totalDurationNotifier.addListener(_updateFromManager);
    _webViewManager.isLiveStreamNotifier.addListener(_updateFromManager);
    _webViewManager.webViewControllerNotifier.addListener(_updateFromManager);
  }

  void _detachListeners() {
    _webViewManager.isLoadingNotifier.removeListener(_updateFromManager);
    _webViewManager.errorMessageNotifier.removeListener(_updateFromManager);
    _webViewManager.isPlayingNotifier.removeListener(_updateFromManager);
    _webViewManager.isPlayerReadyNotifier.removeListener(_updateFromManager);
    _webViewManager.currentPositionNotifier.removeListener(_updateFromManager);
    _webViewManager.totalDurationNotifier.removeListener(_updateFromManager);
    _webViewManager.isLiveStreamNotifier.removeListener(_updateFromManager);
    _webViewManager.webViewControllerNotifier
        .removeListener(_updateFromManager);
  }

  void _updateFromManager() {
    state = state.copyWith(
      isLoading: _webViewManager.isLoadingNotifier.value,
      errorMessage: _webViewManager.errorMessageNotifier.value,
      isPlaying: _webViewManager.isPlayingNotifier.value,
      isPlayerReady: _webViewManager.isPlayerReadyNotifier.value,
      currentPosition: _webViewManager.currentPositionNotifier.value,
      totalDuration: _webViewManager.totalDurationNotifier.value,
      isLiveStream: _webViewManager.isLiveStreamNotifier.value,
      webViewController: _webViewManager.webViewControllerNotifier.value,
    );
  }

  Future<void> _loadInitialSettings() async {
    final String? lastUrl = await SharedPreferencesService.loadLastPlayedUrl();
    final double savedVolume = await SharedPreferencesService.loadVolume();

    state = state.copyWith(volume: savedVolume);

    if (lastUrl != null && lastUrl.isNotEmpty) {
      _ref.read(urlControllerProvider).text = lastUrl;
      loadVideo(lastUrl);
    }
  }

  WebViewController? get webViewController => state.webViewController;

  Future<void> loadVideo(String url) async {
    final videoId = YouTubeUrlParser.extractVideoId(url);
    if (videoId != null) {
      _detachListeners();
      _webViewManager.dispose();
      _webViewManager = YouTubeWebViewManager();
      _attachListeners();

      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        isPlaying: false,
        isPlayerReady: false,
        currentPosition: 0.0,
        totalDuration: 0.0,
        isLiveStream: false,
        showMediaControls: false,
        webViewController: null,
        isFullScreen: false,
      );

      await _webViewManager.initialize(videoId, state.volume, state.isMuted);
      await SharedPreferencesService.saveLastPlayedUrl(url);
    } else {
      state = state.copyWith(
          errorMessage:
              'Invalid YouTube URL format. Please use a valid YouTube video link.');
    }
  }

  void playPause() {
    if (state.isPlaying) {
      _webViewManager.pause();
    } else {
      _webViewManager.play();
    }
  }

  void stop() {
    _webViewManager.stop();
  }

  void setVolume(double newVolume) {
    state = state.copyWith(volume: newVolume, isMuted: false);
    _webViewManager.setVolume(newVolume);
    SharedPreferencesService.saveVolume(newVolume);
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
    _webViewManager.toggleMute();
  }

  void seekTo(double seconds) {
    _webViewManager.seekTo(seconds);
  }

  void onSliderChanged(double value) {
    state = state.copyWith(currentPosition: value);
    _webViewManager.setDraggingSlider(true);
  }

  void toggleControlsVisibility() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void showControls() {
    state = state.copyWith(showControls: true);
  }

  void hideControls() {
    state = state.copyWith(showControls: false);
  }

  void toggleMediaControlsVisibility() {
    state = state.copyWith(showMediaControls: !state.showMediaControls);
    if (state.showMediaControls && !state.showControls) {
      state = state.copyWith(showControls: true);
    }
  }

  Future<void> toggleFullScreen() async {
    final bool currentFullScreenState = await WindowService.isFullScreen();
    await Future.delayed(const Duration(milliseconds: 50));
    await WindowService.setFullScreen(!currentFullScreenState);
  }

  void onWindowFullScreenChanged(bool isCurrentlyFullScreen) {
    state = state.copyWith(isFullScreen: isCurrentlyFullScreen);
    _webViewManager.resizePlayerInWebView();
  }

  // Reset method to load saved volume
  void reset() async {
    _detachListeners();
    _webViewManager.dispose();
    _webViewManager = YouTubeWebViewManager();
    _attachListeners();

    final double savedVolume =
        await SharedPreferencesService.loadVolume(); // Load saved volume

    state = YouTubePlayerState(
      isLoading: false,
      isPlaying: false,
      isPlayerReady: false,
      currentPosition: 0.0,
      totalDuration: 0.0,
      volume: savedVolume, // Use saved volume here
      isMuted: false,
      isLiveStream: false,
      showControls: true,
      showMediaControls: false,
      webViewController: null,
      isFullScreen: false,
    );
    _ref.read(urlControllerProvider).clear();
  }

  @override
  void dispose() {
    _detachListeners();
    _webViewManager.dispose();
    super.dispose();
  }
}

// 3. The actual providers
final youtubePlayerProvider =
    StateNotifierProvider<YouTubePlayerNotifier, YouTubePlayerState>((ref) {
  return YouTubePlayerNotifier(ref);
});

final urlControllerProvider = Provider((ref) => TextEditingController());

final keyboardServiceProvider = Provider((ref) {
  final playerNotifier = ref.watch(youtubePlayerProvider.notifier);
  final service = KeyboardService(
    onSpacePressed: playerNotifier.toggleControlsVisibility,
    onCmdShiftEnterPressed: playerNotifier.toggleFullScreen,
    onPlayPausePressed: playerNotifier.playPause,
    onStopPressed: playerNotifier.stop,
    onQuitPressed: WindowService.close,
    onCmdCPressed: playerNotifier.toggleMediaControlsVisibility,
  );
  service.addHandler();
  ref.onDispose(() {
    service.removeHandler();
  });
  return service;
});
