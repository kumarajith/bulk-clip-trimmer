import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'video_trimmer.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  late final player = Player();
  late final controller = VideoController(player);
  bool _isPlaying = false; // Add play/pause state
  double _volume = 0.0; // Add volume state

  @override
  void initState() {
    super.initState();
    player.stream.volume.listen((volume) {
      setState(() {
        _volume = volume;
      });
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        player.play();
      } else {
        player.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: VideoPlayer(
        onToggleTheme: () {
          setState(() {
            _isDarkMode = !_isDarkMode;
          });
        },
        player: player,
        controller: controller,
        onTogglePlayPause: _togglePlayPause, // Pass the play/pause toggle function
        isPlaying: _isPlaying, // Pass the play/pause state
        volume: _volume, // Pass the volume state
        onVolumeChange: (value) async {
          await player.setVolume(value);
        }, // Pass the volume change function
      ),
    );
  }
}

class _VideoPlayerState extends State<VideoPlayer> {
  final List<String> playlist = [];
  String? currentVideo;
  late Stream<Map<String, Duration>> positionAndDurationStream;

  // State to manage labels and their checkboxes
  final Map<String, bool> labels = {};
  final Map<String, String> labelToFolder = {};
  late RangeValues? _currentTrimRange;
  List<Map<String, dynamic>> _trimJobs = [];
  bool _processingTrims = false;
  bool _showPlaceholderPanel = true; // Add this state
  bool _isAudioOnly = false;

  final StreamController<Map<String, dynamic>> _trimJobController = StreamController.broadcast();
  final Queue<Map<String, dynamic>> _jobQueue = Queue();
  final TextEditingController _fileNameController = TextEditingController();
  List<TextEditingController> _labelControllers = [];

  @override
  void initState() {
    super.initState();
    _currentTrimRange = null;
    _trimJobController.stream.listen((job) async {
      _jobQueue.add(job);
      if (!_processingTrims) {
        _processNextJob();
      };
    });
    _labelControllers = List.generate(labels.length, (index) => TextEditingController());

    positionAndDurationStream = Rx.combineLatest2<Duration, Duration, Map<String, Duration>>(
      widget.player.stream.position,
      widget.player.stream.duration,
      (position, duration) => {'position': position, 'duration': duration},
    );
  }

  @override
  void dispose() {
    _trimJobController.close();
    _fileNameController.dispose();
    for (var controller in _labelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _processNextJob() async {
    if (_jobQueue.isEmpty) {
      setState(() {
        _processingTrims = false;
      });
      return;
    }

    setState(() {
      _processingTrims = true;
    });

    final job = _jobQueue.removeFirst();
    await _processTrimJob(job);

    _processNextJob();
  }

  void labelFoldersWithTable() async {
    final rows = labels.entries.map((entry) {
      return {'label': entry.key, 'folder': labelToFolder[entry.key] ?? ''};
    }).toList();

    if (rows.isEmpty || rows.last['label']!.isNotEmpty && rows.last['folder']!.isNotEmpty) {
      rows.add({'label': '', 'folder': ''});
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Label Folders'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6, // Reduce the overall width of the modal
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: Theme.of(context).dividerColor), // Change border color based on theme
                    columnWidths: {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Label', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Folder', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...rows.map((row) {
                        final index = rows.indexOf(row);
                        if (_labelControllers.length <= index) {
                          _labelControllers.add(TextEditingController(text: row['label']));
                        }
                        return TableRow(
                          children: [
                            SizedBox(
                              height: 60,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Enter label',
                                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      rows[index]['label'] = value;
                                      if (index == rows.length - 1 && value.isNotEmpty && row['folder']!.isNotEmpty) {
                                        rows.add({'label': '', 'folder': ''});
                                      }
                                    });
                                  },
                                  controller: _labelControllers[index],
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 60,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final result = await FilePicker.platform.getDirectoryPath();
                                    if (result != null) {
                                      setDialogState(() {
                                        rows[index]['folder'] = result;
                                        if (index == rows.length - 1 && row['label']!.isNotEmpty && result.isNotEmpty) {
                                          rows.add({'label': '', 'folder': ''});
                                        }
                                      });
                                    }
                                  },
                                  child: Text(
                                    row['folder']?.split('/').last.isNotEmpty == true ? row['folder']!.split('/').last : 'Select Folder',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Theme.of(context).textTheme.labelLarge?.color), // Ensure text is visible
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      labels.clear();
                      labelToFolder.clear();
                      for (var row in rows) {
                        if (row['label']!.isNotEmpty && row['folder']!.isNotEmpty) {
                          labels[row['label']!] = false;
                          labelToFolder[row['label']!] = row['folder']!;
                        }
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void playVideo(String videoPath) {
    setState(() {
      currentVideo = videoPath;
      widget.player.open(Media(videoPath));
      widget.player.setVolume(widget.volume); // Set the volume when a new video is played
      widget.onTogglePlayPause(); // Use the play/pause toggle function from MyAppState
    });
  }

  void _onTrimChangeHandler(RangeValues newRange) {
    setState(() {
      _currentTrimRange = newRange;
    });
  }

  Future<void> _processTrimJob(Map<String, dynamic> job) async {
    final fileName = job['fileName'];
    final start = Duration(milliseconds: (job['start'] * 1000).toInt());
    final end = Duration(milliseconds: (job['end'] * 1000).toInt());
    final audioOnly = job['audioOnly'];
    final folders = job['folders'];

    for (final folder in folders) {
      final outputFilePath = '$folder/${job['outputFileName']}.mp4';

      // Example FFMPEG command
      final command = [
        'ffmpeg',
        '-y', // Automatically overwrite output file if it exists
        '-i', fileName,
        '-ss', start.toString().split('.').first, // Format to HH:MM:SS
        '-to', end.toString().split('.').first, // Format to HH:MM:SS
        if (audioOnly) '-an',
        '-c', 'copy',
        outputFilePath,
      ];

      final process = await Process.start(command[0], command.sublist(1).cast<String>());

      process.stdout.transform(utf8.decoder).listen((data) {
        print('FFMPEG stdout: $data'); // Log stdout
        // Parse FFMPEG output to update progress
        // Example: frame=  100 fps=0.0 q=-1.0 size=       0kB time=00:00:04.00 bitrate=   0.0kbits/s speed=8.01x
        final regex = RegExp(r'time=(\d+):(\d+):(\d+).(\d+)');
        final match = regex.firstMatch(data);
        if (match != null) {
          final hours = int.parse(match.group(1)!);
          final minutes = int.parse(match.group(2)!);
          final seconds = int.parse(match.group(3)!);
          final milliseconds = int.parse(match.group(4)!);
          final currentTime = Duration(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ).inMilliseconds;

          final totalDuration = (end - start).inMilliseconds;
          final progress = currentTime / totalDuration;

          setState(() {
            job['progress'] = progress;
          });
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('FFMPEG stderr: $data'); // Log stderr
      });

      await process.exitCode;
    }

    setState(() {
      job['progress'] = 1.0;
    });
  }

  void _addTrimJob() {
    if (currentVideo == null || _currentTrimRange == null || _fileNameController.text.isEmpty) return;
    final start = _currentTrimRange!.start;
    final end = _currentTrimRange!.end;

    final selectedFolders = labels.entries
        .where((entry) => entry.value == true)
        .map((entry) => labelToFolder[entry.key])
        .whereType<String>()
        .toList();

    final job = {
      'fileName': currentVideo,
      'start': start,
      'end': end,
      'audioOnly': _isAudioOnly,
      'folders': selectedFolders,
      'progress': 0.0,
      'outputFileName': _fileNameController.text,
    };

    setState(() {
      _trimJobs.add(job);
      _fileNameController.clear();
    });

    _trimJobController.add(job);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
            widget.onTogglePlayPause(); // Use the play/pause toggle function from MyAppState
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Video(
                      controller: widget.controller, // Use widget.controller
                      controls: (VideoState state) => SizedBox.shrink(),
                    ),
                  ),
                  Row(
                    children: [
                      // Play/Pause button
                      IconButton(
                        icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: widget.onTogglePlayPause, // Use the play/pause toggle function from MyAppState
                      ),
                      Expanded(
                        child: StreamBuilder<Map<String, Duration>>(
                          stream: positionAndDurationStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();

                            final position = snapshot.data!['position'] ?? Duration.zero;
                            final duration = snapshot.data!['duration'] ?? Duration.zero;
                            return VideoTrimSeekBarWidget(
                              duration: duration,
                              position: position,
                              onPositionChange: (newPosition) async {
                                await widget.player.seek(newPosition); // Use widget.player
                              },
                              onTrimChange: (newRange) {
                                _onTrimChangeHandler(newRange);
                              },
                            );
                          },
                        ),
                      ),
                      // Volume control
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(Icons.volume_up, color: isDarkMode ? Colors.white : Colors.black),
                      ),
                      SizedBox(
                        width: 200,
                        child: Slider(
                          value: widget.volume,
                          min: 0.0,
                          max: 100.0,
                          onChanged: widget.onVolumeChange,
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.folder_open),
                            onPressed: () async {
                              final result = await FilePicker.platform.getDirectoryPath();
                              if (result != null) {
                                final dir = Directory(result);
                                final videos = dir
                                    .listSync()
                                    .where((file) => file.path.endsWith('.mp4') || file.path.endsWith('.mkv'))
                                    .map((file) => file.path)
                                    .toList();
                                setState(() {
                                  playlist.addAll(videos);
                                });
                              }
                            },
                          ),
                          VerticalDivider(),
                          IconButton(
                            icon: const Icon(Icons.label),
                            onPressed: labelFoldersWithTable,
                          ),
                          SizedBox(width: 10),
                          ...labels.keys.map((label) {
                            return Row(
                              children: [
                                Checkbox(
                                  value: labels[label],
                                  onChanged: (bool? value) {
                                    setState(() {
                                      labels[label] = value ?? false;
                                    });
                                  },
                                ),
                                Text(label),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                      VerticalDivider(),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.25,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Checkbox(
                              value: _isAudioOnly,
                              onChanged: (bool? value) {
                                setState(() {
                                  _isAudioOnly = value ?? false;
                                });
                              },
                            ),
                            Icon(Icons.music_note),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _fileNameController,
                                decoration: InputDecoration(hintText: 'Output file name'),
                              ),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _addTrimJob,
                              child: Text('Add to Queue'),
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              icon: Icon(Icons.brightness_6),
                              onPressed: widget.onToggleTheme,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context),
              child: Container(
                width: 400,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: playlist.length,
                        itemBuilder: (context, index) {
                          final videoPath = playlist[index];
                          final fileName = videoPath.split('/').last;
                          return ListTile(
                            title: Text(fileName, overflow: TextOverflow.ellipsis),
                            onTap: () => playVideo(videoPath),
                            selected: currentVideo == videoPath,
                            selectedTileColor: isDarkMode ? Colors.grey[700] : Colors.grey[300], // Highlight selected file
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_showPlaceholderPanel
                              ? Icons.arrow_drop_down
                              : Icons.arrow_drop_up),
                          onPressed: () {
                            setState(() {
                              _showPlaceholderPanel = !_showPlaceholderPanel;
                            });
                          },
                        ),
                        Text('Placeholder Panel'),
                      ],
                    ),
                    Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _showPlaceholderPanel ? 200 : 0,
                        child: _showPlaceholderPanel
                            ? ListView.builder(
                                itemCount: _trimJobs.length,
                                itemBuilder: (context, index) {
                                  final job = _trimJobs[index];
                                  return ListTile(
                                    title: Text(job['fileName']),
                                    subtitle: LinearProgressIndicator(
                                      value: job['progress'],
                                      backgroundColor: Colors.grey,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        job['progress'] == 1.0
                                            ? Colors.green
                                            : job['progress'] == -1.0
                                                ? Colors.red
                                                : Colors.blue,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayer extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final Player player;
  final VideoController controller;
  final VoidCallback onTogglePlayPause; // Add play/pause toggle function
  final bool isPlaying; // Add play/pause state
  final double volume; // Add volume state
  final ValueChanged<double> onVolumeChange; // Add volume change function

  const VideoPlayer({
    Key? key,
    required this.onToggleTheme,
    required this.player,
    required this.controller,
    required this.onTogglePlayPause, // Add play/pause toggle function
    required this.isPlaying, // Add play/pause state
    required this.volume, // Add volume state
    required this.onVolumeChange, // Add volume change function
  }) : super(key: key);

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}