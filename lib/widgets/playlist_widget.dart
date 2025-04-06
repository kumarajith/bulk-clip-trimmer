import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';

/// Widget for displaying the video playlist
class PlaylistWidget extends StatelessWidget {
  /// Constructor
  const PlaylistWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final appState = Provider.of<AppStateProvider>(context, listen: false);

    return Consumer<AppStateProvider>(
      builder: (context, appStateConsumer, _) {
        final videos = appStateConsumer.videos;
        final currentVideo = appStateConsumer.currentVideo;

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
                        onPressed: () => appState.pickVideoFile(),
                      ),
                      // Add folder button
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: 'Add videos from folder',
                        onPressed: () => appState.pickVideoFolder(),
                      ),
                      // Clear playlist button
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        tooltip: 'Clear playlist',
                        onPressed: videos.isEmpty ? null : () => appState.clearPlaylist(),
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
                            onPressed: () => appState.pickVideoFolder(),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final isSelected = currentVideo == video;
                        final fileName = _getFileName(video.filePath);
                        
                        return ListTile(
                          title: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            video.filePath,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.video_file,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withOpacity(0.6),
                                size: 32,
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: theme.colorScheme.onPrimary,
                                      size: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => appStateConsumer.removeVideoFromPlaylist(video),
                          ),
                          selected: isSelected,
                          selectedTileColor: isDarkMode
                              ? Colors.grey[700]
                              : Colors.grey[300],
                          onTap: () => appStateConsumer.playVideo(video),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
  
  /// Extract a clean file name from a file path
  String _getFileName(String filePath) {
    // Handle both forward and backward slashes
    final parts = filePath.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : filePath;
  }
}
