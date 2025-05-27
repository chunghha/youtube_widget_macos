// lib/services/youtube_webview_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YouTubeWebViewManager {
  WebViewController? _webViewController;

  final ValueNotifier<bool> isPlayerReadyNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<double> currentPositionNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> totalDurationNotifier = ValueNotifier(0.0);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLiveStreamNotifier = ValueNotifier(false);
  final ValueNotifier<WebViewController?> webViewControllerNotifier =
      ValueNotifier(null);

  double _currentVolume = 100.0;
  bool _isCurrentlyMuted = false;

  Timer? _progressTimer;
  bool _isDraggingSlider = false;

  WebViewController? get webViewController => _webViewController;

  YouTubeWebViewManager();

  Future<void> initialize(
      String videoId, double initialVolume, bool initialMuted) async {
    _currentVolume = initialVolume;
    _isCurrentlyMuted = initialMuted;

    isLoadingNotifier.value = true;
    isPlayerReadyNotifier.value = false;
    isPlayingNotifier.value = false;
    currentPositionNotifier.value = 0.0;
    totalDurationNotifier.value = 0.0;
    errorMessageNotifier.value = null;
    isLiveStreamNotifier.value = false;
    webViewControllerNotifier.value = null;

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PlayerChannel',
        onMessageReceived: (JavaScriptMessage message) =>
            _onJavaScriptMessage(message.message),
      )
      ..addJavaScriptChannel(
        'ConsoleChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // print('WebView Console: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            isLoadingNotifier.value = true;
          },
          onPageFinished: (String url) {
            isLoadingNotifier.value = false;
          },
          onWebResourceError: (WebResourceError error) {
            isLoadingNotifier.value = false;
            errorMessageNotifier.value = _mapWebResourceError(error);
          },
        ),
      );

    webViewControllerNotifier.value = _webViewController;

    final String htmlContent =
        _generateHtmlContent(videoId, initialVolume, initialMuted);
    await _webViewController!.loadHtmlString(htmlContent);
  }

  Future<void> play() async {
    if (isPlayerReadyNotifier.value) {
      await _webViewController?.runJavaScript('player.playVideo();');
      isPlayingNotifier.value = true;
      _startProgressTimer();
    }
  }

  Future<void> pause() async {
    if (isPlayerReadyNotifier.value) {
      await _webViewController?.runJavaScript('player.pauseVideo();');
      isPlayingNotifier.value = false;
      _stopProgressTimer();
    }
  }

  Future<void> stop() async {
    if (isPlayerReadyNotifier.value) {
      await _webViewController?.runJavaScript('player.stopVideo();');
      isPlayingNotifier.value = false;
      currentPositionNotifier.value = 0.0;
      _stopProgressTimer();
    }
  }

  Future<void> setVolume(double volume) async {
    _currentVolume = volume;
    _isCurrentlyMuted = false;
    if (isPlayerReadyNotifier.value) {
      await _webViewController
          ?.runJavaScript('player.setVolume(${volume.round()});');
      await _webViewController?.runJavaScript('player.unMute();');
    }
  }

  Future<void> toggleMute() async {
    _isCurrentlyMuted = !_isCurrentlyMuted;
    if (isPlayerReadyNotifier.value) {
      if (_isCurrentlyMuted) {
        await _webViewController?.runJavaScript('player.mute();');
      } else {
        await _webViewController?.runJavaScript('player.unMute();');
      }
    }
  }

  Future<void> seekTo(double seconds) async {
    if (isPlayerReadyNotifier.value && !isLiveStreamNotifier.value) {
      await _webViewController?.runJavaScript('player.seekTo($seconds, true);');
      currentPositionNotifier.value = seconds;
      _isDraggingSlider = false;
    }
  }

  Future<void> resizePlayerInWebView() async {
    if (_webViewController != null) {
      await _webViewController?.runJavaScript('resizePlayer();');
    }
  }

  void dispose() {
    _stopProgressTimer();
    _webViewController = null;
    isPlayerReadyNotifier.dispose();
    isPlayingNotifier.dispose();
    currentPositionNotifier.dispose();
    totalDurationNotifier.dispose();
    errorMessageNotifier.dispose();
    isLoadingNotifier.dispose();
    isLiveStreamNotifier.dispose();
    webViewControllerNotifier.dispose();
  }

  String _generateHtmlContent(
      String videoId, double initialVolume, bool initialMuted) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
          <style>
              body { margin: 0; overflow: hidden; background-color: black; }
              #player { width: 100vw; height: 100vh; }
          </style>
      </head>
      <body>
          <div id="player"></div>

          <script>
              var tag = document.createElement('script');
              tag.src = "https://www.youtube.com/iframe_api";
              var firstScriptTag = document.getElementsByTagName('script')[0];
              firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

              var player;

              var initialVolume = ${initialVolume.round()};
              var initialMuted = $initialMuted;

              function resizePlayer() {
                  if (player && typeof player.setSize === 'function') {
                      var width = window.innerWidth;
                      var height = window.innerHeight;
                      player.setSize(width, height);
                  }
              }

              function onYouTubeIframeAPIReady() {
                  player = new YT.Player('player', {
                      videoId: '$videoId',
                      playerVars: {
                          'playsinline': 1,
                          'controls': 0,
                          'enablejsapi': 1,
                          'origin': window.location.origin
                      },
                      events: {
                          'onReady': onPlayerReady,
                          'onStateChange': onPlayerStateChange,
                          'onError': onPlayerError
                      }
                  });
              }

              function onPlayerReady(event) {
                  setTimeout(function() {
                      if (typeof PlayerChannel !== 'undefined') {
                          PlayerChannel.postMessage('playerReady');
                      }
                  }, 50);
                  resizePlayer();

                  player.setVolume(initialVolume);
                  if (initialMuted) {
                      player.mute();
                  } else {
                      player.unMute();
                  }
              }

              function onPlayerStateChange(event) {
                  if (typeof PlayerChannel !== 'undefined') {
                      PlayerChannel.postMessage('state:' + event.data);
                  }
              }

              function onPlayerError(event) {
                  if (typeof PlayerChannel !== 'undefined') {
                      PlayerChannel.postMessage('error:' + event.data);
                  }
              }

              window.addEventListener('resize', resizePlayer);
          </script>
      </body>
      </html>
    ''';
  }

  void _onJavaScriptMessage(String message) {
    if (message == 'playerReady') {
      isPlayerReadyNotifier.value = true;
      errorMessageNotifier.value = null;
      _startProgressTimer();
    } else if (message.startsWith('state:')) {
      final state = int.parse(message.split(':')[1]);
      if (state == 1) {
        isPlayingNotifier.value = true;
        _startProgressTimer();
      } else if (state == 2) {
        isPlayingNotifier.value = false;
        _stopProgressTimer();
      } else if (state == 0) {
        isPlayingNotifier.value = false;
        _stopProgressTimer();
        currentPositionNotifier.value = totalDurationNotifier.value;
      }
    } else if (message.startsWith('error:')) {
      final errorCode = int.parse(message.split(':')[1]);
      errorMessageNotifier.value = _mapYouTubePlayerError(errorCode);
      isLoadingNotifier.value = false;
      isPlayingNotifier.value = false;
    }
  }

  String _mapYouTubePlayerError(int errorCode) {
    switch (errorCode) {
      case 2:
        return 'YouTube Player Error: Invalid video ID or parameters.';
      case 100:
        return 'YouTube Player Error: Video not found or is private.';
      case 101:
      case 150:
        return 'YouTube Player Error: Video cannot be played in embedded players.';
      default:
        return 'YouTube Player Error: An unknown error occurred (Code: $errorCode).';
    }
  }

  String _mapWebResourceError(WebResourceError error) {
    String message = 'Failed to load web resource: ${error.description}';
    if (error.errorCode == -1009) {
      message = 'Network Error: Please check your internet connection.';
    } else if (error.errorCode == -1003) {
      message = 'Host Not Found: The server could not be reached.';
    }
    return message;
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_webViewController != null &&
          isPlayerReadyNotifier.value &&
          isPlayingNotifier.value &&
          !_isDraggingSlider) {
        try {
          final Object? currentTimeResult = await _webViewController
              ?.runJavaScriptReturningResult('player.getCurrentTime();');
          final Object? durationResult = await _webViewController
              ?.runJavaScriptReturningResult('player.getDuration();');

          final double current =
              (currentTimeResult is num) ? currentTimeResult.toDouble() : 0.0;
          final double duration =
              (durationResult is num) ? durationResult.toDouble() : 0.0;

          if (duration == 0.0 || duration.isInfinite || duration > 1000000000) {
            isLiveStreamNotifier.value = true;
            currentPositionNotifier.value = 0.0;
            totalDurationNotifier.value = 0.0;
          } else {
            isLiveStreamNotifier.value = false;
            currentPositionNotifier.value = current;
            totalDurationNotifier.value = duration;
          }
        } catch (e) {
          // Handle JavaScript execution errors gracefully
        }
      } else if (!isPlayingNotifier.value) {
        _progressTimer?.cancel();
        _progressTimer = null;
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void setDraggingSlider(bool isDragging) {
    _isDraggingSlider = isDragging;
  }
}
