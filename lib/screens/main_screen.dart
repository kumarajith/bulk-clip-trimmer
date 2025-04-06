import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/playlist_widget.dart';
import '../widgets/label_folders_widget.dart';
import '../widgets/trim_form_widget.dart';
import '../widgets/trim_jobs_widget.dart';

/// Main screen of the application
class MainScreen extends StatelessWidget {
  /// Video controller
  final VideoController controller;

  /// Constructor
  const MainScreen({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Clip Trimmer'),
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(
              appState.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: appState.toggleDarkMode,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // Left panel - Video player and controls
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Video player
                    Expanded(
                      flex: 3,
                      child: VideoPlayerWidget(
                        controller: controller,
                      ),
                    ),
                    
                    // Divider
                    const Divider(height: 1),
                    
                    // Bottom panel - Label folders and trim form
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label folders
                            Expanded(
                              flex: 2,
                              child: LabelFoldersWidget(),
                            ),
                            
                            // Trim form
                            Expanded(
                              flex: 1,
                              child: TrimFormWidget(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Resizable divider
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    // Calculate new width based on drag
                    final newWidth = appState.playlistPanelWidth - details.delta.dx;
                    appState.setPlaylistPanelWidth(newWidth);
                  },
                  child: Container(
                    width: 8,
                    height: double.infinity,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Right panel - Playlist and jobs (now with dynamic width)
              AnimatedBuilder(
                animation: appState,
                builder: (context, _) {
                  return Container(
                    width: appState.playlistPanelWidth,
                    child: Column(
                      children: [
                        // Playlist
                        Expanded(
                          flex: 2,
                          child: PlaylistWidget(),
                        ),
                        
                        // Trim jobs
                        const Expanded(
                          flex: 1,
                          child: TrimJobsWidget(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
