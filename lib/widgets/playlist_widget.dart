import 'package:flutter/material.dart';

import '../providers/app_state_provider.dart';

/// Widget for displaying the video playlist
class PlaylistWidget extends StatelessWidget {
  /// App state provider
  final AppStateProvider appState;

  /// Constructor
  const PlaylistWidget({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final videos = appState.videos;
        final currentVideo = appState.currentVideo;
        
        return Column(
          children: [
            // Playlist header
            Container(
              padding: const EdgeInsets.all(8.0),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Playlist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Row(
                    children: [
                      // Add video button
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add single video',
                        onPressed: appState.pickVideoFile,
                      ),
                      // Add folder button
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: 'Add videos from folder',
                        onPressed: appState.pickVideoFolder,
                      ),
                      // Clear playlist button
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        tooltip: 'Clear playlist',
                        onPressed: videos.isEmpty ? null : appState.clearPlaylist,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Playlist items
            Expanded(
              child: videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library,
                            size: 48,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No videos in playlist. Add videos using the buttons above.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Videos'),
                            onPressed: appState.pickVideoFolder,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final isSelected = currentVideo == video;
                        final fileName = video.filePath.split('/').last;
                        
                        return ListTile(
                          title: Text(
                            fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            video.filePath,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(
                            Icons.video_file,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => appState.removeVideoFromPlaylist(video),
                          ),
                          selected: isSelected,
                          selectedTileColor: isDarkMode
                              ? Colors.grey[700]
                              : Colors.grey[300],
                          onTap: () => appState.playVideo(video),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
