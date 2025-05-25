// lib/screens/youtube_widget_screen.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_widget_macos/widgets/control_overlay.dart';
import 'package:youtube_widget_macos/widgets/webview_player.dart';
import 'package:youtube_widget_macos/utils/youtube_url_parser.dart';
import 'package:youtube_widget_macos/services/window_service.dart';
import 'package:youtube_widget_macos/services/keyboard_service.dart';
import 'package:youtube_widget_macos/services/shared_preferences_service.dart';
import 'package:youtube_widget_macos/services/youtube_webview_manager.dart';

class YouTubeWidgetScreen extends StatefulWidget {
  const YouTubeWidgetScreen({Key? key}) : super(key: key);

  @override
  State<YouTubeWidgetScreen> createState() => _YouTubeWidgetScreenState();
}

class _YouTubeWidgetScreenState extends State<YouTubeWidgetScreen>
    with WindowListener {
  final TextEditingController _urlController = TextEditingController();
  late YouTubeWebViewManager _webViewManager;
  late KeyboardService _keyboardService;

  bool _isLoading = false;
  bool _showControls = true;
  String? _errorMessage;
  bool _isPlaying = false;
  bool _isPlayerReady = false;
  bool _isFullScreen = false;
  double _volume = 100.0;
  bool _isMuted = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  bool _showMediaControls = false;

  @override
  void initState() {
    super.initState();
    _webViewManager = YouTubeWebViewManager();
    windowManager.addListener(this);
    _initFullScreenState();
    _loadLastPlayedUrl();

    _webViewManager.isLoadingNotifier.addListener(_updateLoadingState);
    _webViewManager.errorMessageNotifier.addListener(_updateErrorMessage);
    _webViewManager.isPlayingNotifier.addListener(_updatePlayingState);
    _webViewManager.isPlayerReadyNotifier.addListener(_updatePlayerReadyState);
    _webViewManager.currentPositionNotifier.addListener(_updateCurrentPosition);
    _webViewManager.totalDurationNotifier.addListener(_updateTotalDuration);

    _keyboardService = KeyboardService(
      onSpacePressed: _toggleControlsVisibility,
      onCmdShiftEnterPressed: _toggleFullScreen,
      onPlayPausePressed: _playPauseVideo,
      onStopPressed: _stopVideo,
      onQuitPressed: WindowService.close,
      onCmdCPressed: _toggleMediaControlsVisibility,
    );
    _keyboardService.addHandler();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _urlController.dispose();
    _keyboardService.removeHandler();

    _webViewManager.isLoadingNotifier.removeListener(_updateLoadingState);
    _webViewManager.errorMessageNotifier.removeListener(_updateErrorMessage);
    _webViewManager.isPlayingNotifier.removeListener(_updatePlayingState);
    _webViewManager.isPlayerReadyNotifier
        .removeListener(_updatePlayerReadyState);
    _webViewManager.currentPositionNotifier
        .removeListener(_updateCurrentPosition);
    _webViewManager.totalDurationNotifier.removeListener(_updateTotalDuration);
    _webViewManager.dispose();

    super.dispose();
  }

  void _updateLoadingState() =>
      setState(() => _isLoading = _webViewManager.isLoadingNotifier.value);
  void _updateErrorMessage() => setState(
      () => _errorMessage = _webViewManager.errorMessageNotifier.value);
  void _updatePlayingState() =>
      setState(() => _isPlaying = _webViewManager.isPlayingNotifier.value);
  void _updatePlayerReadyState() => setState(
      () => _isPlayerReady = _webViewManager.isPlayerReadyNotifier.value);
  void _updateCurrentPosition() => setState(
      () => _currentPosition = _webViewManager.currentPositionNotifier.value);
  void _updateTotalDuration() => setState(
      () => _totalDuration = _webViewManager.totalDurationNotifier.value);

  void _loadLastPlayedUrl() async {
    final String? lastUrl = await SharedPreferencesService.loadLastPlayedUrl();
    if (lastUrl != null && lastUrl.isNotEmpty) {
      _urlController.text = lastUrl;
      _loadVideo();
    }
  }

  void _toggleFullScreen() async {
    final bool currentFullScreenState = await WindowService.isFullScreen();
    await WindowService.setFullScreen(!currentFullScreenState);
    await Future.delayed(const Duration(milliseconds: 100));
    final bool newState = await WindowService.isFullScreen();
    setState(() {
      _isFullScreen = newState;
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleMediaControlsVisibility() {
    setState(() {
      _showMediaControls = !_showMediaControls;
      if (_showMediaControls && !_showControls) {
        _showControls = true;
      }
    });
  }

  void _initFullScreenState() async {
    _isFullScreen = await WindowService.isFullScreen();
    setState(() {});
  }

  void _loadVideo() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoId = YouTubeUrlParser.extractVideoId(url);

    if (videoId != null) {
      _webViewManager.initialize(videoId, _volume, _isMuted);
      SharedPreferencesService.saveLastPlayedUrl(url);
    } else {
      setState(() {
        _errorMessage =
            'Invalid YouTube URL format. Please use a valid YouTube video link.';
      });
      _showErrorDialog(_errorMessage!);
    }
  }

  void _playPauseVideo() {
    if (_isPlaying) {
      _webViewManager.pause();
    } else {
      _webViewManager.play();
    }
  }

  void _stopVideo() {
    _webViewManager.stop();
  }

  void _setVolume(double newVolume) {
    setState(() {
      _volume = newVolume;
      _isMuted = false;
    });
    _webViewManager.setVolume(newVolume);
  }

  void _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    _webViewManager.toggleMute();
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentPosition = value;
    });
    _webViewManager.setDraggingSlider(true);
  }

  void _seekTo(double seconds) {
    _webViewManager.seekTo(seconds);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void onWindowMaximize() {
    _updateFullScreenState();
  }

  @override
  void onWindowUnmaximize() {
    _updateFullScreenState();
  }

  @override
  void onWindowEnterFullScreen() {
    _updateFullScreenState();
    _webViewManager.resizePlayerInWebView();
  }

  @override
  void onWindowExitFullScreen() {
    _updateFullScreenState();
    _webViewManager.resizePlayerInWebView();
  }

  void _updateFullScreenState() async {
    final bool currentFullScreenState = await WindowService.isFullScreen();
    if (_isFullScreen != currentFullScreenState) {
      setState(() {
        _isFullScreen = currentFullScreenState;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) => setState(() => _showControls = true),
        onExit: (_) => setState(() => _showControls = false),
        child: Stack(
          children: [
            WebViewPlayer(
              webController: _webViewManager.webViewController,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
            ),
            ControlOverlay(
              showControls: _showControls,
              urlController: _urlController,
              onLoadVideo: _loadVideo,
              onPlayPause: _playPauseVideo,
              onStop: _stopVideo,
              onLoadNewVideo: () {
                _urlController.clear();
                _webViewManager.dispose();
                _webViewManager = YouTubeWebViewManager();
                _webViewManager.isLoadingNotifier
                    .addListener(_updateLoadingState);
                _webViewManager.errorMessageNotifier
                    .addListener(_updateErrorMessage);
                _webViewManager.isPlayingNotifier
                    .addListener(_updatePlayingState);
                _webViewManager.isPlayerReadyNotifier
                    .addListener(_updatePlayerReadyState);
                _webViewManager.currentPositionNotifier
                    .addListener(_updateCurrentPosition);
                _webViewManager.totalDurationNotifier
                    .addListener(_updateTotalDuration);

                setState(() {
                  _isLoading = false;
                  _errorMessage = null;
                  _isPlaying = false;
                  _isPlayerReady = false;
                  _volume = 100.0;
                  _isMuted = false;
                  _currentPosition = 0.0;
                  _totalDuration = 0.0;
                  _showMediaControls = false;
                });
              },
              onMinimize: WindowService.minimize,
              onClose: WindowService.close,
              onDragStart: WindowService.startDragging,
              isPlaying: _isPlaying,
              webControllerExists: _webViewManager.webViewController != null,
              errorMessage: _errorMessage,
              volume: _volume,
              isMuted: _isMuted,
              onVolumeChanged: _setVolume,
              onToggleMute: _toggleMute,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              onSeek: _seekTo,
              onSliderChanged: _onSliderChanged,
              showMediaControls: _showMediaControls,
              onToggleControlsIcon: _toggleMediaControlsVisibility,
            ),
          ],
        ),
      ),
    );
  }
}
