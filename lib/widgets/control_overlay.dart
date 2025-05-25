// lib/widgets/control_overlay.dart
import 'package:flutter/material.dart';

class ControlOverlay extends StatelessWidget {
  final bool showControls;
  final TextEditingController urlController;
  final VoidCallback onLoadVideo;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onLoadNewVideo;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final VoidCallback onDragStart;
  final bool isPlaying;
  final bool webControllerExists;
  final bool hasError;

  const ControlOverlay({
    Key? key,
    required this.showControls,
    required this.urlController,
    required this.onLoadVideo,
    required this.onPlayPause,
    required this.onStop,
    required this.onLoadNewVideo,
    required this.onMinimize,
    required this.onClose,
    required this.onDragStart,
    required this.isPlaying,
    required this.webControllerExists,
    required this.hasError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !showControls,
      child: AnimatedOpacity(
        opacity: showControls ? 1.0 : 0.0,
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
                    Expanded(
                      child: GestureDetector(
                        onPanStart: (details) {
                          onDragStart();
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
                    IconButton(
                      onPressed: onMinimize,
                      icon: const Icon(
                        Icons.minimize,
                        color: Colors.white70,
                        size: 16,
                      ),
                      tooltip: 'Minimize',
                    ),
                    IconButton(
                      onPressed: onClose,
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

              // Bottom controls
              if (!webControllerExists)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // URL Input
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: TextField(
                          controller: urlController,
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
                          onSubmitted: (_) => onLoadVideo(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: onLoadVideo,
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
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: onPlayPause,
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white70,
                          size: 24,
                        ),
                        tooltip: isPlaying ? 'Pause' : 'Play',
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: onStop,
                        icon: const Icon(
                          Icons.stop,
                          color: Colors.white70,
                          size: 24,
                        ),
                        tooltip: 'Stop Video',
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: onLoadNewVideo,
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
    );
  }
}
