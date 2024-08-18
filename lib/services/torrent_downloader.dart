import 'dart:async';
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:dtorrent_task/src/task.dart';
import 'package:dtorrent_task/src/task_events.dart';
import 'package:events_emitter2/events_emitter2.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

// TorrentDownloader class extends ChangeNotifier to provide reactive state management
class TorrentDownloader extends ChangeNotifier{
  final String torrentFilePath;
  final String savePath;
  late TorrentTask _task;
  late String name = "";
  late int size =0;
  Timer? _timer;
  late EventsListener<TaskEvent> _listener;
  late double progress = 0.0;
  late int activePeers = 0;
  late int TotalPeers = 0;
  late int seeders = 0;
  late int state = 0;
  late String pathfinal = "";
  late String speed = "0 kb/s";
  late Torrent model;

  // Constructor for TorrentDownloader class
  TorrentDownloader({
    required this.torrentFilePath,
    required this.savePath,
  });

  // Method to start the download
  Future<void> startDownload() async {
    try {
      // Parse the torrent file
      model = await Torrent.parse(torrentFilePath);
      // Create a new torrent task
      _task = TorrentTask.newTask(model, savePath);
      name = model.name;
      size  =model.length;
      _listener = _task.createListener();
      _listener
        ..on<TaskCompleted>((event) {
          // Log when the download is complete
          developer.log('Download Complete!');
          state = 1;
          progress = 1.0;
          onProgressUpdate();
          stopDownload();
        })
        ..on<TaskStopped>((event) {
          // Log when the download is stopped
          developer.log('Download Stopped');
          state = progress==1 ? 1 : 2;
          onProgressUpdate();
        })
        ..on<TaskResumed>((event){
          // Update the state when the download is resumed
          state = 0;
        });
      // Start the task
      await _task.start();
      _startProgressMonitoring();
    } catch (e) {
      // Log any errors that occur when starting the download
      developer.log('Error starting download: $e');
    }
  }

  // Method to resume the download
  Future<void> resumeDownload() async {
    _task.resume();
    state = 0;
    _startProgressMonitoring();
  }

  // Method to start monitoring the progress of the download
  void _startProgressMonitoring() {
    _timer = Timer.periodic(Duration(seconds: 3), (timer) async {
      var downloadSpeed = (_task.currentDownloadSpeed * 1000 / 1024).toStringAsFixed(2);
      var uploadSpeed = (_task.uploadSpeed * 1000 / 1024).toStringAsFixed(2);
      speed = downloadSpeed;
      activePeers = _task.connectedPeersNumber;
      TotalPeers = _task.allPeersNumber;
      seeders= _task.seederNumber;
      developer.log(_task.pieceManager?.downloadingPieces.toString() ?? "");
      developer.log('Progress: ${(progress * 100).toStringAsFixed(2)}%, Download speed: $downloadSpeed kb/s, Upload speed: $uploadSpeed kb/s total peers: $TotalPeers active peers : $activePeers seeders : $seeders downloaded : $state downloaded : ${_task.downloaded} size = $size');
      onProgressUpdate();
    });
  }

  // Method to update the progress of the download
  void onProgressUpdate() {
    notifyListeners(); 
  }

  // Method to wake up the download
  void wakeup() async {
   _task.pieceManager?.pieces.forEach((key,piece){
      if ((piece.isCompleted==true) & (piece.isCompletelyDownloaded == false) & (piece.isCompletelyWritten==true)){
             _task.processPieceRejected(piece.index);
      }
   });
   _task.pieceManager?.pieces[_task.pieceManager?.pieces.keys.last]?.dispose();
  }

  // Method to pause the download
  void pauseDownload(){
    _task.pause();
    _timer?.cancel();
    state = progress==1 ? 1 : 2;
    notifyListeners();
  }
  
  // Method to stop the download
  void stopDownload() {
    _timer?.cancel();
    _task.stop();
  }
}