// lib/widgets/webview_player.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPlayer extends StatelessWidget {
  final WebViewController? webController;
  final bool isLoading;
  final String? errorMessage;

  const WebViewPlayer({
    Key? key,
    required this.webController,
    required this.isLoading,
    required this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (webController != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            WebViewWidget(controller: webController!),
            if (isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
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
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              errorMessage != null
                  ? Icons.error_outline
                  : Icons.play_circle_outline,
              size: 64,
              color: errorMessage != null ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Enter a YouTube URL to start',
              style: TextStyle(
                color: errorMessage != null ? Colors.red : Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}
