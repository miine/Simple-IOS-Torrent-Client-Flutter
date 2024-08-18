import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path/path.dart' as path;
import 'package:torrent_client/services/files.dart';
import 'package:torrent_client/services/torrent_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:torrent_client/file_tab.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock/wakelock.dart';
import 'dart:developer' as developer;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => TorrentManager(),
      child: MyApp(),
    ),
  );
}

// TorrentManager class to manage the list of TorrentDownloaders
class TorrentManager extends ChangeNotifier {
  List<TorrentDownloader> _torrentDownloaders = [];

  List<TorrentDownloader> get torrentDownloaders => _torrentDownloaders;

  void addDownloader(TorrentDownloader downloader) {
    downloader.addListener(() {
      notifyListeners(); // Notify listeners when a progress changes
    });
    _torrentDownloaders.add(downloader);
    notifyListeners();
  }
}

// MyApp is the main application widget
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentSub;

  @override
  void initState() {
    super.initState();
    Wakelock.enable();

    _performInitialAction();

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value[0].path);
      }
    }, onError: (err) {
      developer.log("getIntentDataStream error: $err");
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value[0].path);
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (err) {
      developer.log("getInitialMedia error: $err");
    });
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

// Function to convert bytes to human readable format
String humanReadableSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  } else if (bytes < 1048576) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  } else if (bytes < 1073741824) {
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  } else if (bytes < 1099511627776) {
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  } else {
    return '${(bytes / 1099511627776).toStringAsFixed(2)} TB';
  }
}

// Function to perform initial actions when the app starts
void _performInitialAction() async{
    var files = await loadTorrentFiles();
    files.forEach((file){
      _handleSharedFile(file.path);
    });
  }

// Function to handle shared files
  Future<void> _handleSharedFile(String filePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      String newTOrrentFileName = path.join(directory.path,path.basename(filePath));
      if (newTOrrentFileName!=filePath){
          moveFile(File(filePath),newTOrrentFileName);
      }
      
      var downloader = TorrentDownloader(
        torrentFilePath: newTOrrentFileName,
        savePath: directory.path,
      );

      // Add the downloader to the TorrentManager
      context.read<TorrentManager>().addDownloader(downloader);

      await downloader.startDownload();
    } catch (e) {
      developer.log("Error handling shared file: $e");
    }
  }

// Building the main application widget
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Torrent Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
       home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Torrent Client'),
            bottom: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.download), text: "Torrents"),
                Tab(icon: Icon(Icons.folder), text: "Files"),
              ],
            ),
          ),
        body : TabBarView(
        children: [
        Consumer<TorrentManager>(
          builder: (context, torrentManager, child) {
            return Column(
              children: [
                HeaderInfo(torrentCount: torrentManager.torrentDownloaders.length),
                Expanded(
                  child: ListView.builder(
                    itemCount: torrentManager.torrentDownloaders.length,
                    itemBuilder: (context, index) {
                      
                      final downloads = torrentManager.torrentDownloaders[index];
                      return TorrentTile(
                        size: 'Peers : (${downloads.activePeers}/${downloads.TotalPeers}) Seeders : ${downloads.seeders} Speed : ${downloads.speed} kb/s Size : ${humanReadableSize(downloads.size)}',
                        name: downloads.name,
                        progress: downloads.progress,
                        state : downloads.state,
                        downloader: downloads,
                      );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              // Second Tab : Displaying files in the iOS container
              FilesTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget to display header information
class HeaderInfo extends StatelessWidget {
  final int torrentCount;

  HeaderInfo({required this.torrentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[100],
      padding: EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InfoTile(label: "Total", count: torrentCount),
        ],
      ),
    );
  }
}

// Widget to display information tile
class InfoTile extends StatelessWidget {
  final String label;
  final int count;

  InfoTile({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4.0),
        Text(
          count.toString(),
          style: TextStyle(fontSize: 20.0),
        ),
      ],
    );
  }
}

// Widget to display torrent tile
class TorrentTile extends StatelessWidget {
  final String size;
  final String name;
  final double progress;
  final int state;
  final TorrentDownloader downloader;

  TorrentTile({required this.size, required this.name, required this.progress, required this.state, required this.downloader});

  @override
  Widget build(BuildContext context) {
  var colorProgress = Colors.blue;
    if (state==1){
      colorProgress = Colors.green;
    }
    if (state==0){
      colorProgress = Colors.blue;
    }
    if (state==2){
      colorProgress = Colors.yellow;
    }
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Text(
          name,
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(size),
            SizedBox(height: 8.0),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              color: colorProgress,
              minHeight: 5.0,
            ),
            SizedBox(height: 8.0),
            Text('${(progress * 100).toStringAsFixed(1)}%'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            _handleMenuAction(value, context);
          },
          itemBuilder: (context) {
            return <PopupMenuEntry<String>>[
            if(state==0)
              PopupMenuItem<String>(
                value: 'wakeup',
                child: Text('Wake up'),
              ),
            if(state==0)
              PopupMenuItem<String>(
                value: 'stop',
                child: Text('Stop'),
              ),
              if(state==2)
              PopupMenuItem<String>(
                value: 'resume',
                child: Text('Resume'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
              if (progress == 1.0) // Display the option only if the download is complete
                PopupMenuItem<String>(
                  value: 'open',
                  child: Text('Open'),
                ),
            ];
          },
        ),
      ),
    );
  }
  void _handleMenuAction(String value, BuildContext context) async {
    switch (value) {
      case 'wakeup':
        downloader.wakeup();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download wakeup')),
        );
        break;
      case 'stop':
        downloader.pauseDownload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download paused')),
        );
        break;
      case 'resume':
        downloader.resumeDownload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download resumed')),
        );
        break;
      case 'delete':
        downloader.stopDownload();

        var files = await searchFilesByName(downloader.name);
        files.forEach((file) async {
          try {
            if (file is File) {
              await file.delete(); // Delete the file
            } else if (file is Directory) {
              await file.delete(recursive: true); // Delete the directory and all its content
            }
          } catch (e) {
            developer.log('Error deleting file or directory ${file.path}: $e');
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download and file(s) deleted')),
          );
        
        break;
      case 'open':
        final filePath = path.join(downloader.savePath, downloader.name);
        if (await File(filePath).exists()) {
          // Open the file with the appropriate application
          try {
            OpenFile.open(filePath); 
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error opening the file.')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The file does not exist.')),
          );
        }
        break;
    }
  }
}