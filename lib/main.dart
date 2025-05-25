import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart'; // Import services for HardwareKeyboard

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Configure window properties
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 400), // Square window
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Frameless
    windowButtonVisibility: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(300, 300));
    // IMPORTANT: The actual fix for fullscreen was in macos/Runner/MainFlutterWindow.swift
    // where maxFullScreenContentSize was set to a larger value (e.g., 1728x1080).
    // This line here sets the *windowed* max size, which is fine.
    await windowManager.setMaximumSize(const Size(800, 800));
    await windowManager.setAlwaysOnTop(true); // Always on top
  });

  runApp(const YouTubeWidgetApp());
}

class YouTubeWidgetApp extends StatelessWidget {
  const YouTubeWidgetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Widget',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const YouTubeWidget(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class YouTubeWidget extends StatefulWidget {
  const YouTubeWidget({Key? key}) : super(key: key);

  @override
  State<YouTubeWidget> createState() => _YouTubeWidgetState();
}

class _YouTubeWidgetState extends State<YouTubeWidget> with WindowListener {
  final TextEditingController _urlController = TextEditingController();
  WebViewController? _webController;
  String? _videoId;
  bool _isLoading = false;
  bool _showControls = true;
  bool _hasError = false;
  bool _isPlaying = false; // Track playback state
  bool _isPlayerReady = false; // Track if YouTube player API is ready
  bool _isFullScreen = false; // Track fullscreen state

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initFullScreenState(); // Initialize fullscreen state
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler); // Add global keyboard listener
  }

  // HardwareKeyboard handler for global shortcuts
  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is KeyDownEvent) {
      final Set<LogicalKeyboardKey> pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;

      // Toggle controls with Space key
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() {
          _showControls = !_showControls;
        });
        return true; // Consume the event
      }
      // Toggle fullscreen with Cmd+Shift+Enter
      else if ((pressedKeys.contains(LogicalKeyboardKey.metaLeft) || pressedKeys.contains(LogicalKeyboardKey.metaRight)) &&
               (pressedKeys.contains(LogicalKeyboardKey.shiftLeft) || pressedKeys.contains(LogicalKeyboardKey.shiftRight)) &&
               event.logicalKey == LogicalKeyboardKey.enter) {
        _toggleFullScreen(); // Call the method to toggle fullscreen
        return true; // Consume the event
      }
    }
    return false; // Let other handlers process the event
  }

  // Fullscreen toggle logic
  void _toggleFullScreen() async {
    final bool currentFullScreenState = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!currentFullScreenState);
    await Future.delayed(const Duration(milliseconds: 100)); // Small delay for native transition
    final bool newState = await windowManager.isFullScreen(); // Get actual new state
    setState(() {
      _isFullScreen = newState; // Update based on actual state
    });
  }

  // Initialize fullscreen state
  void _initFullScreenState() async {
    _isFullScreen = await windowManager.isFullScreen();
    setState(() {}); // Update UI if needed based on initial state
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _urlController.dispose();
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler); // Remove global keyboard listener
    super.dispose();
  }

  String? _extractVideoId(String url) {
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:embed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }

  void _loadVideo() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoId = _extractVideoId(url);

    if (videoId != null) {
      setState(() {
        _videoId = videoId;
        _hasError = false;
        _isLoading = true;
        _isPlayerReady = false; // Reset player ready state for new video
        _isPlaying = false; // Reset playback state
      });
      _initializeWebView(videoId);
    } else {
      setState(() {
        _hasError = true;
      });
      _showErrorDialog('Invalid YouTube URL. Try formats like:\n'
          '• https://www.youtube.com/watch?v=VIDEO_ID\n'
          '• https://youtu.be/VIDEO_ID');
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
            _webController?.runJavaScript('resizePlayer();'); // Call resize function
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
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
                  resizePlayer(); // Initial resize
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

              window.addEventListener('resize', resizePlayer); // Listen for WebView resize
          </script>
      </body>
      </html>
    ''';

    _webController!.loadHtmlString(htmlContent);
  }

  // Handler for messages received from JavaScript
  void _onJavaScriptMessage(String message) {
    if (message == 'playerReady') {
      setState(() {
        _isPlayerReady = true;
      });
    } else if (message.startsWith('state:')) {
      final state = int.parse(message.split(':')[1]);
      // YT.PlayerState constants: -1 (unstarted), 0 (ended), 1 (playing), 2 (paused), 3 (buffering), 5 (video cued)
      setState(() {
        if (state == 1) { // Playing
          _isPlaying = true;
        } else if (state == 2) { // Paused
          _isPlaying = false;
        } else if (state == 0) { // Ended
          _isPlaying = false;
        }
      });
    } else if (message.startsWith('error:')) {
      final errorCode = message.split(':')[1];
      setState(() {
        _hasError = true;
        _isLoading = false;
        _isPlaying = false;
      });
      _showErrorDialog('YouTube Player Error: $errorCode. This might be due to video restrictions or network issues.');
    }
  }

  // JavaScript functions to control the YouTube player
  void _playVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.playVideo();');
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.pauseVideo();');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _stopVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.stopVideo();');
      setState(() {
        _isPlaying = false;
      });
    }
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

  // Override window listener for fullscreen changes
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
    _webController?.runJavaScript('resizePlayer();'); // Trigger WebView resize
  }

  @override
  void onWindowExitFullScreen() {
    _updateFullScreenState();
    _webController?.runJavaScript('resizePlayer();'); // Trigger WebView resize
  }

  void _updateFullScreenState() async {
    final bool currentFullScreenState = await windowManager.isFullScreen();
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
            // YouTube Player (WebView)
            if (_webController != null)
              Container(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    WebViewWidget(controller: _webController!),
                    if (_isLoading)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading video...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasError
                          ? Icons.error_outline
                          : Icons.play_circle_outline,
                      size: 64,
                      color: _hasError ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _hasError
                          ? 'Failed to load video'
                          : 'Enter a YouTube URL to start',
                      style: TextStyle(
                        color: _hasError ? Colors.red : Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    if (_hasError) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                          });
                        },
                        child: const Text('Clear Error'),
                      ),
                    ],
                  ],
                ),
              ),

            // Control Overlay
            IgnorePointer( // Ignore pointer events when controls are not shown
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Top controls
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            // Drag handle (for moving window)
                            Expanded(
                              child: GestureDetector(
                                onPanStart: (details) {
                                  windowManager.startDragging();
                                },
                                child: Container(
                                  height: 32,
                                  color: Colors.transparent,
                                  child: const Center(
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Minimize button
                            IconButton(
                              onPressed: () => windowManager.minimize(),
                              icon: const Icon(
                                Icons.minimize,
                                color: Colors.white70,
                                size: 16,
                              ),
                              tooltip: 'Minimize',
                            ),
                            // Close button
                            IconButton(
                              onPressed: () => windowManager.close(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 16,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Bottom controls (only show when no video is loaded)
                      if (_webController == null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // URL Input
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[700]!),
                                ),
                                child: TextField(
                                  controller: _urlController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Paste YouTube URL here...',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    suffixIcon: Icon(
                                      Icons.link,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onSubmitted: (_) => _loadVideo(),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Action buttons
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _loadVideo,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Load Video'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else // Controls when video is playing
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                               IconButton(
                                onPressed: _isPlaying ? _pauseVideo : _playVideo,
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white70,
                                  size: 24, // Slightly larger icon for play/pause
                                ),
                                tooltip: _isPlaying ? 'Pause' : 'Play',
                              ),
                              const SizedBox(width: 16), // Spacing between buttons
                              IconButton(
                                onPressed: _stopVideo, // Call the new stop function
                                icon: const Icon(
                                  Icons.stop,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                                tooltip: 'Stop Video',
                              ),
                              const SizedBox(width: 16), // Spacing between buttons
                              IconButton(
                                onPressed: () {
                                  // Reset button state when loading new video
                                  setState(() {
                                    _urlController.clear();
                                    _webController = null;
                                    _videoId = null;
                                    _isLoading = false;
                                    _hasError = false;
                                    _isPlaying = false; // Reset playback state
                                    _isPlayerReady = false; // Reset player ready state
                                  });
                                },
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                tooltip: 'Load New Video',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
