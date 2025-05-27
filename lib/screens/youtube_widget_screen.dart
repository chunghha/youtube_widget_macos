// lib/screens/youtube_widget_screen.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_widget_macos/widgets/control_overlay.dart';
import 'package:youtube_widget_macos/widgets/webview_player.dart';
import 'package:youtube_widget_macos/providers/player_providers.dart';
import 'package:youtube_widget_macos/services/window_service.dart';
import 'package:youtube_widget_macos/services/keyboard_service.dart';

class YouTubeWidgetScreen extends ConsumerStatefulWidget {
  const YouTubeWidgetScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<YouTubeWidgetScreen> createState() =>
      _YouTubeWidgetScreenState();
}

class _YouTubeWidgetScreenState extends ConsumerState<YouTubeWidgetScreen>
    with WindowListener {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initFullScreenState();

    ref.read(keyboardServiceProvider);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
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
  }

  @override
  void onWindowExitFullScreen() {
    _updateFullScreenState();
  }

  void _updateFullScreenState() async {
    final bool currentFullScreenState = await WindowService.isFullScreen();
    if (_isFullScreen != currentFullScreenState) {
      setState(() {
        _isFullScreen = currentFullScreenState;
      });
      ref
          .read(youtubePlayerProvider.notifier)
          .onWindowFullScreenChanged(currentFullScreenState);
    }
  }

  void _initFullScreenState() async {
    _isFullScreen = await WindowService.isFullScreen();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(youtubePlayerProvider);
    final playerNotifier = ref.read(youtubePlayerProvider.notifier);
    final urlController = ref.read(urlControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) => playerNotifier.showControls(),
        onExit: (_) => playerNotifier.hideControls(),
        child: Stack(
          children: [
            WebViewPlayer(
              webController: playerState.webViewController,
              isLoading: playerState.isLoading,
              errorMessage: playerState.errorMessage,
            ),
            ControlOverlay(
              showControls: playerState.showControls,
              urlController: urlController,
              onLoadVideo: () => playerNotifier.loadVideo(urlController.text),
              onPlayPause: playerNotifier.playPause,
              onStop: playerNotifier.stop,
              onLoadNewVideo: () {
                urlController.clear();
                playerNotifier.loadVideo('');
              },
              onMinimize: WindowService.minimize,
              onClose: WindowService.close,
              onDragStart: WindowService.startDragging,
              isPlaying: playerState.isPlaying,
              webControllerExists: playerState.webViewController != null,
              errorMessage: playerState.errorMessage,
              volume: playerState.volume,
              isMuted: playerState.isMuted,
              onVolumeChanged: playerNotifier.setVolume,
              onToggleMute: playerNotifier.toggleMute,
              currentPosition: playerState.currentPosition,
              totalDuration: playerState.totalDuration,
              onSeek: playerNotifier.seekTo,
              onSliderChanged: playerNotifier.onSliderChanged,
              showMediaControls: playerState.showMediaControls,
              onToggleControlsIcon:
                  playerNotifier.toggleMediaControlsVisibility,
              isLiveStream: playerState.isLiveStream,
            ),
          ],
        ),
      ),
    );
  }
}
