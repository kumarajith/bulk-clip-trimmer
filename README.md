# Bulk Clip Trimmer

A Flutter application for batch trimming video files with a custom seekbar and folder management.

## Features

- Custom video seekbar with trim area selection
- Batch processing of trim jobs
- Folder management for organizing output files
- Support for multiple output folders per trim job
- Audio-only extraction option
- Dark/light theme toggle
- FFmpeg integration for video processing

## Architecture

The application follows a clean architecture approach with:

- **Models**: Data structures for the application
- **Services**: Business logic and external integrations
- **Providers**: State management
- **Widgets**: Reusable UI components
- **Screens**: Main application views

## Getting Started

1. Ensure you have Flutter installed on your system
2. Make sure FFmpeg is installed and available in your system PATH
3. Clone this repository
4. Run `flutter pub get` to install dependencies
5. Run `flutter run` to start the application

## Usage

1. Add videos to the playlist using the folder or file buttons
2. Select a video from the playlist to load it
3. Use the seekbar to set the trim range (green handles)
4. Configure output folders with labels
5. Select output folders for the current trim job
6. Enter an output file name
7. Click "Add to Queue" to add the trim job
8. Jobs will process automatically in the background

## Dependencies

- media_kit: Video playback
- rxdart: Reactive programming
- file_picker: File and directory selection
