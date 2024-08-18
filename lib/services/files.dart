import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


/// Returns the path of the application directory.
/// On Android, it returns the path of the external storage directory.
/// On other platforms, it returns the path of the application documents directory.
Future<String> get getAppDirectoryPath async {
  if (Platform.isAndroid) {
    final directory = await getExternalStorageDirectory();
    return directory!.path;
  } else {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
}

/// Moves a file from the [sourceFile] path to the [newPath].
/// If the file can be renamed successfully, it is renamed and the renamed file is returned.
/// If the file cannot be renamed, it is copied to the [newPath], the original file is deleted, and the copied file is returned.
/// Throws a [FileSystemException] if an error occurs during the file operation.
Future<File> moveFile(File sourceFile, String newPath) async {
  try {
    return await sourceFile.rename(newPath);
  } on FileSystemException {
    final newFile = await sourceFile.copy(newPath);
    await sourceFile.delete();
    return newFile;
  }
}

/// Loads the torrent files from the application documents directory.
///
/// Returns a list of [FileSystemEntity] objects representing the filtered torrent files.
Future<List<FileSystemEntity>> loadTorrentFiles() async {
  final directory = await getApplicationDocumentsDirectory();
  final allFiles = directory.listSync();
  final _whitelistExtensions = [".torrent"];

  final filteredFiles = allFiles.where((file) {
    final ext = path.extension(file.path).toLowerCase();
    return _whitelistExtensions.contains(ext);
  }).toList();

  return filteredFiles;
}

/// Searches for files in the application documents directory that match the given query.
///
/// The [query] parameter is the name or part of the name of the files to search for.
/// Returns a list of [FileSystemEntity] objects representing the matching files.
Future<List<FileSystemEntity>> searchFilesByName(String query) async {
  final directory = await getApplicationDocumentsDirectory();
  final allFiles = directory.listSync();

  final filteredFiles = allFiles.where((file) {
    final fileName = path.basename(file.path).toLowerCase();
    return fileName.contains(query.toLowerCase());
  }).toList();

  return filteredFiles;
}


Future<bool> isFileExists(String filePath) async {
  return await File(filePath).exists();
}

Future<void> deleteFile(String filePath) async {
  if (await isFileExists(filePath) == true) {
    await File(filePath).delete();
  }
}

Future<String> getFilePath(String fileName) async {
  String appDirPath = await getAppDirectoryPath;
  String filePath = '$appDirPath/$fileName';
  bool isExists = await isFileExists(filePath);
  if (isExists == true) {
    return filePath;
  }
  throw "File Not Exists";
}