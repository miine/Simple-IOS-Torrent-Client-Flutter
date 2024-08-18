import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


  // Get the icon corresponding to the file extension
IconData _getIconForExtension(String extension) {
  Map<String, IconData> extensionIconMap = {
    '.pdf': Icons.book,
    '.epub': Icons.book,
    '.mkv': Icons.movie,
    '.mp4': Icons.movie,
    '.avi': Icons.movie,
    '.mp3': Icons.music_note,
    '.wav': Icons.music_note,
    '.jpg': Icons.image,
    '.jpeg': Icons.image,
    '.png': Icons.image,
    '.gif': Icons.image,
    '.doc': Icons.description,
    '.docx': Icons.description,
    '.txt': Icons.description,
    '.zip': Icons.archive,
    '.rar': Icons.archive,
  };

  return extensionIconMap[extension] ?? Icons.insert_drive_file;
}

// Main class for the file tab
class FilesTab extends StatefulWidget {
  @override
  _FilesTabState createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  late Future<List<FileSystemEntity>> _filesFuture;

  // List of extensions to exclude
  final List<String> _blacklistExtensions = ['.tmp', '.log', '.dat', '.state', '.torrent'];

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadFiles();
  }

  // Load, filter and sort files
  Future<List<FileSystemEntity>> _loadFiles([String? dirPath]) async {
    final directory = dirPath == null
        ? await getApplicationDocumentsDirectory()
        : Directory(dirPath);
    final allFiles = directory.listSync();

    // Filter files based on the blacklist
    final filteredFiles = allFiles.where((file) {
      final ext = path.extension(file.path).toLowerCase();
      return !_blacklistExtensions.contains(ext) || file is Directory;
    }).toList();

    // Sort files and folders alphabetically
    filteredFiles.sort((a, b) => path.basename(a.path).toLowerCase().compareTo(path.basename(b.path).toLowerCase()));

    return filteredFiles;
  }

  // Refresh the file list
  Future<void> _refreshFiles() async {
    setState(() {
      _filesFuture = _loadFiles();
    });
  }

  // Get the icon corresponding to the file type
  IconData _getFileIcon(FileSystemEntity file) {
    if (file is Directory) {
      return Icons.folder; // Icon for folders
    }

    final extension = path.extension(file.path).toLowerCase();
    return _getIconForExtension(extension);
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileSystemEntity>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error loading files'));
        } else {
          final files = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refreshFiles, // Function called on refresh gesture
            child: _buildFileList(files),
          );
        }
      },
    );
  }

  // Build the file list
  Widget _buildFileList(List<FileSystemEntity> files) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = path.basename(file.path);
        final fileIcon = _getFileIcon(file);

        if (file is Directory) {
          return DirectoryTile(
            directory: file,
            icon: fileIcon,
            blacklistExtensions: _blacklistExtensions,
          );
        } else {
          return ListTile(
            leading: Icon(fileIcon, color: Colors.blue),
            title: Text(fileName),
            onTap: () async {
              if (await File(file.path).exists()) {
                OpenFile.open(file.path);
              }
            },
          );
        }
      },
    );
  }
}

// Class for directory tiles
class DirectoryTile extends StatefulWidget {
  final Directory directory;
  final IconData icon;
  final List<String> blacklistExtensions;

  DirectoryTile({
    required this.directory,
    required this.icon,
    required this.blacklistExtensions,
  });

  @override
  _DirectoryTileState createState() => _DirectoryTileState();
}

class _DirectoryTileState extends State<DirectoryTile> {
  late Future<List<FileSystemEntity>> _subFilesFuture;

  @override
  void initState() {
    super.initState();
    _subFilesFuture = _loadSubFiles();
  }

  // Load sub-files
  Future<List<FileSystemEntity>> _loadSubFiles() async {
    final allFiles = widget.directory.listSync();

    // Filter files based on the blacklist
    final filteredFiles = allFiles.where((file) {
      final ext = path.extension(file.path).toLowerCase();
      return !widget.blacklistExtensions.contains(ext) || file is Directory;
    }).toList();

    // Sort files and folders alphabetically
    filteredFiles.sort((a, b) => path.basename(a.path).toLowerCase().compareTo(path.basename(b.path).toLowerCase()));

    return filteredFiles;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileSystemEntity>>(
      future: _subFilesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: Icon(widget.icon, color: Colors.amber),
            title: Text(path.basename(widget.directory.path)),
            trailing: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return ListTile(
            leading: Icon(widget.icon, color: Colors.amber),
            title: Text(path.basename(widget.directory.path)),
            trailing: Icon(Icons.error, color: Colors.red),
          );
        } else {
          final subFiles = snapshot.data ?? [];
          return ExpansionTile(
            leading: Icon(widget.icon, color: Colors.amber),
            title: Text(path.basename(widget.directory.path)),
            children: subFiles.map((subFile) {
              final subFileName = path.basename(subFile.path);
              final subFileIcon = _getFileIcon(subFile);

              if (subFile is Directory) {
                return DirectoryTile(
                  directory: subFile,
                  icon: Icons.folder,
                  blacklistExtensions: widget.blacklistExtensions,
                );
              } else {
                return ListTile(
                  leading: Icon(subFileIcon, color: Colors.blue),
                  title: Text(subFileName),
                  onTap: () async {
                    if (await File(subFile.path).exists()) {
                      OpenFile.open(subFile.path);
                    }
                  },
                );
              }
            }).toList(),
          );
        }
      },
    );
  }

  // Get the icon corresponding to the file type
  IconData _getFileIcon(FileSystemEntity file) {
    if (file is Directory) {
      return Icons.folder; // Icon for folders
    }

    final extension = path.extension(file.path).toLowerCase();
    return _getIconForExtension(extension);
  }


}

