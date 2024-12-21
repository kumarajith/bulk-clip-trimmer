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

void main() {
  MediaKit.ensureInitialized();
  runApp(
    const MaterialApp(
      home: VideoPlayer(),
    ),
  );
}

class _VideoPlayerState extends State<VideoPlayer> {
  late final player = Player();
  late final controller = VideoController(player);
  final List<String> playlist = [];
  String? currentVideo;

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

  @override
  void initState() {
    super.initState();
    _currentTrimRange = null;
    _trimJobController.stream.listen((job) async {
      _jobQueue.add(job);
      if (!_processingTrims) {
        _processNextJob();
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    _trimJobController.close();
    _fileNameController.dispose();
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
    final rows = <Map<String, String>>[]; // Each row will store {'label': '...', 'folder': '...'}

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Label Folders'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Table Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Label', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Folder', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Rows of Labels and Folders
                    Expanded(
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return Row(
                            children: [
                              // Label Input
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(hintText: 'Enter label'),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      rows[index]['label'] = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              // Folder Selection Button
                              ElevatedButton(
                                onPressed: () async {
                                  final result = await FilePicker.platform.getDirectoryPath();
                                  if (result != null) {
                                    setDialogState(() {
                                      rows[index]['folder'] = result;
                                    });
                                  }
                                },
                                child: Text(
                                  row['folder']?.split('/').last ?? 'Select Folder',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                    // Add New Row Button
                    ElevatedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          rows.add({'label': '', 'folder': ''});
                        });
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add Row'),
                    ),
                  ],
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
      player.open(Media(videoPath));
      player.setVolume(0.0);
    });
  }

  void _onTrimChangeHandler(RangeValues newRange) {
    setState(() {
      _currentTrimRange = newRange;
    });
  }

  Future<void> _processTrimJob(Map<String, dynamic> job) async {
    final fileName = job['fileName'];
    final start = job['start'];
    final end = job['end'];
    final audioOnly = job['audioOnly'];
    final folders = job['folders'];

    for (final folder in folders) {
      final outputFilePath = '$folder/${job['outputFileName']}.mp4';

      // Example FFMPEG command
      final command = [
        'ffmpeg',
        '-y', // Automatically overwrite output file if it exists
        '-i', fileName,
        '-ss', start.toString(),
        '-to', end.toString(),
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

          final totalDuration = (end - start) * 1000;
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
    final positionAndDurationStream = Rx.combineLatest2<Duration, Duration, Map<String, Duration>>(
      player.stream.position,
      player.stream.duration,
      (position, duration) => {'position': position, 'duration': duration},
    );

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Video(
                    controller: controller,
                    controls: (VideoState state) => SizedBox.shrink(),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.volume_up, color: Colors.black),
                    SizedBox(
                      width: 200,
                      child: StreamBuilder<double>(
                        stream: player.stream.volume,
                        builder: (context, snapshot) {
                          final volume = snapshot.data ?? 0.0;
                          return Slider(
                            value: volume,
                            min: 0.0,
                            max: 100.0,
                            onChanged: (value) async {
                              await player.setVolume(value);
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<Map<String, Duration>>(
                        stream: positionAndDurationStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();

                          final position = snapshot.data!['position'] ?? Duration.zero;
                          final duration = snapshot.data!['duration'] ?? Duration.zero;
                          return VideoTrimSeekBar(
                            duration: duration,
                            position: position,
                            onPositionChange: (newPosition) async {
                              await player.seek(newPosition);
                            },
                            onTrimChange: (newRange) {
                              _onTrimChangeHandler(newRange);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
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
                    IconButton(
                      icon: const Icon(Icons.label),
                      onPressed: labelFoldersWithTable,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTrimJob,
                    ),
                    Checkbox(
                      value: _isAudioOnly,
                      onChanged: (bool? value) {
                        setState(() {
                          _isAudioOnly = value ?? false;
                        });
                      },
                    ),
                    Text('Audio only'),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: labels.entries.map((entry) {
                            return Row(
                              children: [
                                Checkbox(
                                  value: entry.value,
                                  onChanged: (isChecked) {
                                    setState(() {
                                      labels[entry.key] = isChecked ?? false;
                                    });
                                  },
                                ),
                                Text(entry.key),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _fileNameController,
                        decoration: InputDecoration(hintText: 'Enter output file name'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 400,
            color: Colors.grey[200],
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _showPlaceholderPanel ? 200 : 0,
                  color: Colors.grey[300],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayer extends StatefulWidget {
  const VideoPlayer({Key? key}) : super(key: key);

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}
