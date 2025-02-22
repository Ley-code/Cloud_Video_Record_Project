import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _backgroundHandler(RemoteMessage message) async {
  print(
      'Background message received: ${message.notification?.title}, ${message.notification?.body}');
  HomePage.startRecordingExternally();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print(
        'Foreground message received: ${message.notification?.title}, ${message.notification?.body}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }

    HomePage.startRecordingExternally();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static _HomePageState? _homePageState;

  static void startRecordingExternally() {
    _homePageState?._startRecording();
  }

  @override
  State<HomePage> createState() {
    _homePageState = _HomePageState();
    return _homePageState!;
  }
}

class _HomePageState extends State<HomePage> {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  bool _isRecording = false;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    getFCMToken();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showSnackBar('No cameras available');
        return;
      }
      _controller = CameraController(_cameras[0], ResolutionPreset.high);
      await _controller.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showSnackBar('Error initializing camera: $e');
    }
  }

  Future<void> getFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    if (token != null) {
      print("FCM Token: $token");
    } else {
      print("Failed to get FCM token.");
    }
  }

  Future<void> _startRecording() async {
    if (!_controller.value.isInitialized || _isRecording) return;

    final directory = await getTemporaryDirectory();
    final videoPath = path.join(directory.path, '${DateTime.now()}.mp4');
    try {
      await _controller.startVideoRecording();
      setState(() {
        _isRecording = true;
      });

      await Future.delayed(const Duration(seconds: 15));

      final XFile videoFile = await _controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = videoFile.path;
        _showSnackBar('Video Recorded Successfully!');
      });
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Recording App',
            style: TextStyle(color: Color.fromARGB(255, 206, 13, 13))),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: CameraPreview(_controller),
                )
              : const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isRecording ? null : _startRecording,
            child: const Text('Start Recording'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _videoPath != null
                ? () => _showSnackBar('Upload feature coming soon!')
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Upload Video'),
          ),
        ],
      ),
    );
  }
}
