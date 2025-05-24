import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart'; // Import services for RawKeyboardListener

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
    await windowManager.setMaximumSize(const Size(800, 800));
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
  String _debugInfo = '';
  bool _hasError = false;
  final FocusNode _focusNode = FocusNode(); // Add FocusNode
  bool _isPlaying = false; // Track playback state
  bool _isPlayerReady = false; // New: Track if YouTube player API is ready

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _focusNode.requestFocus(); // Request focus when the widget initializes
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _urlController.dispose();
    _focusNode.dispose(); // Dispose FocusNode
    super.dispose();
  }

  String? _extractVideoId(String url) {
    // Handle different YouTube URL formats
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

    print('Attempting to load URL: $url');

    final videoId = _extractVideoId(url);
    print('Extracted video ID: $videoId');

    if (videoId != null) {
      setState(() {
        _videoId = videoId;
        _hasError = false;
        _debugInfo = 'Loading video ID: $videoId';
        _isLoading = true;
        _isPlayerReady = false; // Reset player ready state for new video
        _isPlaying = false; // Reset playback state
      });

      _initializeWebView(videoId);
    } else {
      setState(() {
        _hasError = true;
        _debugInfo = 'Invalid URL format';
      });
      _showErrorDialog('Invalid YouTube URL. Try formats like:\n'
          '• https://www.youtube.com/watch?v=VIDEO_ID\n'
          '• https://youtu.be/VIDEO_ID');
    }
  }

  void _initializeWebView(String videoId) {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Add JavaScriptChannel to receive messages from the WebView
      ..addJavaScriptChannel(
        'PlayerChannel', // Channel for player events
        onMessageReceived: (JavaScriptMessage message) {
          _onJavaScriptMessage(message.message);
        },
      )
      // NEW: Add JavaScriptChannel for console messages
      ..addJavaScriptChannel(
        'ConsoleChannel', // Channel for console logs
        onMessageReceived: (JavaScriptMessage message) {
          print('WebView Console: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
            setState(() {
              _isLoading = true;
              _debugInfo = 'Loading video...';
            });
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            setState(() {
              _isLoading = false;
              _debugInfo = 'Video loaded successfully!';
              _hasError = false;
            });
            // No need to inject API here, it's part of the HTML string
          },
          onWebResourceError: (WebResourceError error) {
            // Print available error details
            print('Web resource error: '
                'Description: ${error.description}, '
                'ErrorCode: ${error.errorCode}');
            setState(() {
              _isLoading = false;
              _hasError = true;
              _debugInfo = 'Failed to load: ${error.description}';
            });
          },
        ),
      );

    // Load an HTML string that includes the YouTube iframe and the API script
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
              // NEW: Override console.log to send messages to Flutter
              var originalLog = console.log;
              console.log = function(message) {
                  originalLog.apply(console, arguments); // Still log to native console if available
                  if (typeof ConsoleChannel !== 'undefined') {
                      ConsoleChannel.postMessage(message);
                  }
              };
              var originalError = console.error;
              console.error = function(message) {
                  originalError.apply(console, arguments);
                  if (typeof ConsoleChannel !== 'undefined') {
                      ConsoleChannel.postMessage('ERROR: ' + message);
                  }
              };

              console.log('HTML content loaded. Attempting to load YouTube API script.');
              var tag = document.createElement('script');
              tag.src = "https://www.youtube.com/iframe_api";
              var firstScriptTag = document.getElementsByTagName('script')[0];
              firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

              var player;
              function onYouTubeIframeAPIReady() {
                  console.log('onYouTubeIframeAPIReady fired. Creating player.');
                  player = new YT.Player('player', {
                      videoId: '$videoId',
                      playerVars: {
                          'playsinline': 1,
                          'controls': 1,
                          'enablejsapi': 1,
                          'origin': window.location.origin // Changed origin to actual WebView origin
                      },
                      events: {
                          'onReady': onPlayerReady,
                          'onStateChange': onPlayerStateChange,
                          'onError': onPlayerError // Add error handling for player
                      }
                  });
              }

              function onPlayerReady(event) {
                  console.log('onPlayerReady fired. Player is ready.');
                  // Notify Flutter that the player is ready
                  // Using a small delay to ensure PlayerChannel is fully initialized
                  setTimeout(function() {
                      if (typeof PlayerChannel !== 'undefined') {
                          PlayerChannel.postMessage('playerReady');
                          console.log('PlayerReady message sent to Flutter.');
                      } else {
                          console.error('PlayerChannel is not defined in WebView after timeout.');
                      }
                  }, 50); // Small delay
              }

              function onPlayerStateChange(event) {
                  console.log('onPlayerStateChange: ' + event.data);
                  // Notify Flutter about player state changes
                  if (typeof PlayerChannel !== 'undefined') {
                      PlayerChannel.postMessage('state:' + event.data);
                  }
              }

              function onPlayerError(event) {
                  console.error('YouTube Player Error: ' + event.data);
                  if (typeof PlayerChannel !== 'undefined') {
                      PlayerChannel.postMessage('error:' + event.data);
                  }
              }
          </script>
      </body>
      </html>
    ''';

    print('Loading HTML content for video ID: $videoId');
    _webController!.loadHtmlString(htmlContent);
  }

  // Handler for messages received from JavaScript
  void _onJavaScriptMessage(String message) {
    print('Received JS message: $message');
    if (message == 'playerReady') {
      setState(() {
        _isPlayerReady = true;
        _debugInfo = 'YouTube player API ready.';
      });
    } else if (message.startsWith('state:')) {
      final state = int.parse(message.split(':')[1]);
      // YT.PlayerState constants:
      // -1 (unstarted), 0 (ended), 1 (playing), 2 (paused), 3 (buffering), 5 (video cued)
      setState(() {
        if (state == 1) {
          // Playing
          _isPlaying = true;
          _debugInfo = 'Video is playing.';
        } else if (state == 2) {
          // Paused
          _isPlaying = false;
          _debugInfo = 'Video is paused.';
        } else if (state == 0) {
          // Ended
          _isPlaying = false;
          _debugInfo = 'Video ended.';
        }
      });
    } else if (message.startsWith('error:')) {
      final errorCode = message.split(':')[1];
      setState(() {
        _hasError = true;
        _debugInfo = 'YouTube Player Error: $errorCode';
        _isLoading = false;
        _isPlaying = false;
      });
      _showErrorDialog(
          'YouTube Player Error: $errorCode. This might be due to video restrictions or network issues.');
    }
  }

  // JavaScript functions to control the YouTube player
  void _playVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.playVideo();');
      setState(() {
        _isPlaying = true;
      });
    } else {
      print('Player not ready to play.');
      setState(() {
        _debugInfo = 'Player not ready yet. Please wait.';
      });
    }
  }

  void _pauseVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.pauseVideo();');
      setState(() {
        _isPlaying = false;
      });
    } else {
      print('Player not ready to pause.');
      setState(() {
        _debugInfo = 'Player not ready yet. Please wait.';
      });
    }
  }

  void _stopVideo() {
    if (_isPlayerReady) {
      _webController?.runJavaScript('player.stopVideo();');
      setState(() {
        _isPlaying = false;
        _debugInfo = 'Video stopped.';
      });
    } else {
      print('Player not ready to stop.');
      setState(() {
        _debugInfo = 'Player not ready yet. Cannot stop.';
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

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() {
          _showControls = !_showControls;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        // Wrap with RawKeyboardListener
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        child: MouseRegion(
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
                      if (_debugInfo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _debugInfo,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _debugInfo = '';
                              _hasError = false;
                            });
                          },
                          child: const Text('Clear Debug Info'),
                        ),
                      ],
                    ],
                  ),
                ),

              // Control Overlay
              IgnorePointer(
                // Ignore pointer events when controls are not shown
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
                              // Close button
                              IconButton(
                                onPressed: () => windowManager.close(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 16,
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[700]!),
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
                          ),

                        // Controls when video is playing
                        if (_webController != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed:
                                      _isPlaying ? _pauseVideo : _playVideo,
                                  icon: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white70,
                                    size:
                                        24, // Slightly larger icon for play/pause
                                  ),
                                  tooltip: _isPlaying ? 'Pause' : 'Play',
                                ),
                                const SizedBox(
                                    width: 16), // Spacing between buttons
                                IconButton(
                                  onPressed:
                                      _stopVideo, // Call the new stop function
                                  icon: const Icon(
                                    Icons.stop,
                                    color: Colors.white70,
                                    size: 24,
                                  ),
                                  tooltip: 'Stop Video',
                                ),
                                const SizedBox(
                                    width: 16), // Spacing between buttons
                                IconButton(
                                  onPressed: () {
                                    // Reset button state when loading new video
                                    setState(() {
                                      _urlController.clear();
                                      _webController = null;
                                      _videoId = null;
                                      _isLoading = false;
                                      _debugInfo = '';
                                      _hasError = false;
                                      _isPlaying =
                                          false; // Reset playback state
                                      _isPlayerReady =
                                          false; // Reset player ready state
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
      ),
    );
  }
}
