// lib/screens/youtube_widget_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_widget_macos/widgets/control_overlay.dart';
import 'package:youtube_widget_macos/widgets/webview_player.dart';
import 'package:youtube_widget_macos/utils/youtube_url_parser.dart';
import 'package:youtube_widget_macos/services/window_service.dart';
import 'package:youtube_widget_macos/services/keyboard_service.dart';
import 'package:youtube_widget_macos/services/shared_preferences_service.dart';

class YouTubeWidgetScreen extends StatefulWidget {
  const YouTubeWidgetScreen({Key? key}) : super(key: key);

  @override
  State<YouTubeWidgetScreen> createState() => _YouTubeWidgetScreenState();
}

class _YouTubeWidgetScreenState extends State<YouTubeWidgetScreen>
    with WindowListener {
  final TextEditingController _urlController = TextEditingController();
  WebViewController? _webController;
  String? _videoId;
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
  Timer? _progressTimer;
  bool _isDraggingSlider = false;

  late KeyboardService _keyboardService;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initFullScreenState();
    _loadLastPlayedUrl();

    _keyboardService = KeyboardService(
      onSpacePressed: _toggleControlsVisibility,
      onCmdShiftEnterPressed: _toggleFullScreen,
      onPlayPausePressed: _playPauseVideo,
      onStopPressed: _stopVideo,
      onQuitPressed: WindowService.close,
    );
    _keyboardService.addHandler();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _urlController.dispose();
    _keyboardService.removeHandler();
    _stopProgressTimer();
    super.dispose();
  }

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

  void _initFullScreenState() async {
    _isFullScreen = await WindowService.isFullScreen();
    setState(() {});
  }

  void _loadVideo() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoId = YouTubeUrlParser.extractVideoId(url);

    if (videoId != null) {
      setState(() {
        _videoId = videoId;
        _errorMessage = null;
        _isLoading = true;
        _isPlayerReady = false;
        _isPlaying = false;
        _currentPosition = 0.0;
        _totalDuration = 0.0;
      });
      _initializeWebView(videoId);
    } else {
      setState(() {
        _errorMessage =
            'Invalid YouTube URL format. Please use a valid YouTube video link.';
      });
      _showErrorDialog(_errorMessage!);
    }
  }

  void _initializeWebView(String videoId) {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PlayerChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _onJavaScriptMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _webController?.runJavaScript('resizePlayer();');
          },
          onWebResourceError: (WebResourceError error) {
            String message =
                'Failed to load web resource: ${error.description}';
            if (error.errorCode == -1009) {
              message = 'Network Error: Please check your internet connection.';
            } else if (error.errorCode == -1003) {
              message = 'Host Not Found: The server could not be reached.';
            }
            setState(() {
              _isLoading = false;
              _errorMessage = message;
            });
            _showErrorDialog(_errorMessage!);
          },
        ),
      );

    final String htmlContent = '''
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

              var initialVolume = ${_volume.round()};
              var initialMuted = $_isMuted;

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
                          'controls': 1,
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

    _webController!.loadHtmlString(htmlContent);
  }

  void _onJavaScriptMessage(String message) {
    if (message == 'playerReady') {
      setState(() {
        _isPlayerReady = true;
        _errorMessage = null;
      });
      _startProgressTimer();
      SharedPreferencesService.saveLastPlayedUrl(_urlController.text);
    } else if (message.startsWith('state:')) {
      final state = int.parse(message.split(':')[1]);
      setState(() {
        if (state == 1) {
          _isPlaying = true;
          _startProgressTimer();
        } else if (state == 2) {
          _isPlaying = false;
          _stopProgressTimer();
        } else if (state == 0) {
          _isPlaying = false;
          _stopProgressTimer();
          _currentPosition = _totalDuration;
        }
      });
    } else if (message.startsWith('error:')) {
      final errorCode = int.parse(message.split(':')[1]);
      String errorMessage;
      switch (errorCode) {
        case 2:
          errorMessage =
              'YouTube Player Error: Invalid video ID or parameters.';
          break;
        case 100:
          errorMessage = 'YouTube Player Error: Video not found or is private.';
          break;
        case 101:
        case 150:
          errorMessage =
              'YouTube Player Error: Video cannot be played in embedded players.';
          break;
        default:
          errorMessage =
              'YouTube Player Error: An unknown error occurred (Code: $errorCode).';
      }
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
        _isPlaying = false;
      });
      _showErrorDialog(_errorMessage!);
    }
  }

  void _playPauseVideo() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _playVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.playVideo();');
      setState(() {
        _isPlaying = true;
      });
      _startProgressTimer();
    }
  }

  void _pauseVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.pauseVideo();');
      setState(() {
        _isPlaying = false;
      });
      _stopProgressTimer();
    }
  }

  void _stopVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.stopVideo();');
      setState(() {
        _isPlaying = false;
        _currentPosition = 0.0;
      });
      _stopProgressTimer();
    }
  }

  void _setVolume(double newVolume) {
    if (_webController != null && _isPlayerReady) {
      setState(() {
        _volume = newVolume;
        _isMuted = false;
      });
      _webController?.runJavaScript('player.setVolume(${newVolume.round()});');
      _webController?.runJavaScript('player.unMute();');
    } else {
      setState(() {
        _volume = newVolume;
      });
    }
  }

  void _toggleMute() async {
    if (_webController != null && _isPlayerReady) {
      final bool currentlyMuted = _isMuted;
      if (currentlyMuted) {
        await _webController?.runJavaScript('player.unMute();');
      } else {
        await _webController?.runJavaScript('player.mute();');
      }
      setState(() {
        _isMuted = !currentlyMuted;
      });
    } else {
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentPosition = value;
      _isDraggingSlider = true;
    });
  }

  void _seekTo(double seconds) {
    if (_webController != null && _isPlayerReady) {
      _webController?.runJavaScript('player.seekTo($seconds, true);');
      setState(() {
        _currentPosition = seconds;
        _isDraggingSlider = false;
      });
    }
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (mounted &&
          _webController != null &&
          _isPlayerReady &&
          _isPlaying &&
          !_isDraggingSlider) {
        try {
          final Object? currentTimeResult = await _webController
              ?.runJavaScriptReturningResult('player.getCurrentTime();');
          final Object? durationResult = await _webController
              ?.runJavaScriptReturningResult('player.getDuration();');

          final double? current =
              (currentTimeResult is num) ? currentTimeResult.toDouble() : null;
          final double? duration =
              (durationResult is num) ? durationResult.toDouble() : null;

          if (current != null && duration != null) {
            if (mounted) {
              setState(() {
                _currentPosition = current;
                _totalDuration = duration;
              });
            }
          }
        } catch (e) {
          // Handle JavaScript execution errors gracefully
        }
      } else if (!_isPlaying) {
        _stopProgressTimer();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
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
    _webController?.runJavaScript('resizePlayer();');
  }

  @override
  void onWindowExitFullScreen() {
    _updateFullScreenState();
    _webController?.runJavaScript('resizePlayer();');
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
              webController: _webController,
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
                setState(() {
                  _urlController.clear();
                  _webController = null;
                  _videoId = null;
                  _isLoading = false;
                  _errorMessage = null;
                  _isPlaying = false;
                  _isPlayerReady = false;
                  _volume = 100.0;
                  _isMuted = false;
                  _currentPosition = 0.0;
                  _totalDuration = 0.0;
                });
                _stopProgressTimer();
              },
              onMinimize: WindowService.minimize,
              onClose: WindowService.close,
              onDragStart: WindowService.startDragging,
              isPlaying: _isPlaying,
              webControllerExists: _webController != null,
              errorMessage: _errorMessage,
              volume: _volume,
              isMuted: _isMuted,
              onVolumeChanged: _setVolume,
              onToggleMute: _toggleMute,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              onSeek: _seekTo,
              onSliderChanged: _onSliderChanged,
            ),
          ],
        ),
      ),
    );
  }
}
