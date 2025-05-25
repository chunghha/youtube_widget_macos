// lib/widgets/control_overlay.dart
import 'package:flutter/material.dart';
import 'package:youtube_widget_macos/config/app_config.dart';

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
  final String? errorMessage;

  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  final double currentPosition;
  final double totalDuration;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSliderChanged;

  final bool showMediaControls;
  final VoidCallback onToggleControlsIcon;

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
    required this.errorMessage,
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
    required this.onSliderChanged,
    required this.showMediaControls,
    required this.onToggleControlsIcon,
  }) : super(key: key);

  String _formatDuration(double seconds) {
    final int minutes = (seconds ~/ 60);
    final int remainingSeconds = (seconds % 60).round();
    final int hours = (minutes ~/ 60);
    final int remainingMinutes = (minutes % 60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${remainingMinutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${remainingMinutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

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
                Colors.black.withAlpha((255 * 0.8).round()),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withAlpha((255 * 0.8).round()),
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
                            hintText: AppConfig.initialUrlInputHint,
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
                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onLoadNewVideo,
                          child: const Text('Clear Error',
                              style: TextStyle(color: Colors.orange)),
                        ),
                      ],
                    ],
                  ),
                )
              else // Controls when video is playing
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Play/Pause/Stop/New Video buttons AND Toggle Controls Icon (aligned horizontally)
                      Row(
                        // Use MainAxisAlignment.spaceBetween to push ends, then Spacers for centering
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Spacer to help center the main buttons
                          const Spacer(),
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
                          // Right Spacer to help center the main buttons
                          const Spacer(),
                          // Toggle Media Controls Icon Button (pushed to far right)
                          IconButton(
                            onPressed: onToggleControlsIcon,
                            icon: Icon(
                              showMediaControls
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                              size: 20,
                            ),
                            tooltip: showMediaControls
                                ? 'Hide Media Controls'
                                : 'Show Media Controls',
                          ),
                        ],
                      ),
                      if (showMediaControls) ...[
                        const SizedBox(height: 8),

                        // Progress Bar
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                _formatDuration(currentPosition),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: currentPosition,
                                min: 0,
                                max: totalDuration > 0 ? totalDuration : 0.0,
                                onChanged: onSliderChanged,
                                onChangeEnd: onSeek,
                                activeColor: Colors.cyan[700],
                                inactiveColor: Colors.grey,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                _formatDuration(totalDuration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Volume Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: onToggleMute,
                              icon: Icon(
                                isMuted || volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white70,
                                size: 20,
                              ),
                              tooltip:
                                  isMuted || volume == 0 ? 'Unmute' : 'Mute',
                            ),
                            Expanded(
                              // Volume Slider
                              child: Slider(
                                value: volume,
                                min: 0,
                                max: 100,
                                divisions: 100,
                                onChanged: onVolumeChanged,
                                activeColor: Colors.red,
                                inactiveColor: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
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
