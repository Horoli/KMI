import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Korean Musical Instruments', home: ViewTest());
  }
}

class ViewTest extends StatefulWidget {
  @override
  _ViewTestState createState() => _ViewTestState();
}

class _ViewTestState extends State<ViewTest> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
              child: Container(width: 1000, height: 1000, color: Colors.green)),
          // Image.asset('assets/images/test.png'),
          Center(
            child: SizedBox(
              width: 800,
              height: 800,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                ),
                itemCount: 10,
                itemBuilder: (context, index) {
                  return TestWidget(
                    sequence: index,
                    imagePath: 'assets/images/test.png',
                    soundPath: 'assets/sounds/Pyeongyeoing_1.opus',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TestWidget extends StatefulWidget {
  final int sequence;
  final String soundPath;
  final String imagePath;
  TestWidget({
    required this.sequence,
    required this.soundPath,
    required this.imagePath,
    super.key,
  });

  @override
  TestWidgetState createState() => TestWidgetState();
}

class TestWidgetState extends State<TestWidget> {
  ui.Image? _image;
  Uint8List? _imageBytes;

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTapDown: (TapDownDetails details) async {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPosition = box.globalToLocal(details.globalPosition);

        bool isTransparent = await _isTransparentAt(localPosition);

        if (!isTransparent) {
          ByteData soundByte =
              await rootBundle.load('assets/sounds/Kkwaenggwari_1_1.opus');
          // await rootBundle.load('assets/sounds/Pyeongyeoing_1.opus');
          Uint8List convertSound = soundByte.buffer.asUint8List();

          final AudioPlayer audioPlayer = AudioPlayer();
          MyCustomSource source = MyCustomSource(convertSound);

          await audioPlayer.setAudioSource(source);

          audioPlayer.play();
          audioPlayer.processingStateStream.listen((state) {
            print('sequence ${widget.sequence} state $state');
            if (state == ProcessingState.ready) {
            } else if (state == ProcessingState.completed) {
              print('state ${widget.sequence} Completed');
              audioPlayer.pause();
              audioPlayer.dispose();
            }
          });
        }
      },
      child: SizedBox(
        width: _image!.width.toDouble(),
        height: _image!.height.toDouble(),
        // child: Container(color: Colors.red)
        child: CustomPaint(
          painter: _ImagePainter(image: _image!),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadImage();
  }

  Future<void> loadImage() async {
    final ByteData data = await rootBundle.load(widget.imagePath);
    _imageBytes = data.buffer.asUint8List();
    final Completer<ui.Image> completer = Completer();

    ui.decodeImageFromList(_imageBytes!, (ui.Image img) {
      setState(() {
        _image = img;
      });
      completer.complete(img);
    });
  }

  Future<bool> _isTransparentAt(Offset localPosition) async {
    if (_image == null || _imageBytes == null) return false;

    final pixelData =
        await _image!.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixelData == null) return false;

    int pixelIndex =
        ((localPosition.dy * _image!.width + localPosition.dx) * 4).toInt();
    if (pixelIndex < 0 || pixelIndex >= pixelData.lengthInBytes) return false;

    // 알파 채널 값 가져오기 (RGBA 형식에서 마지막 바이트)
    int alphaValue = pixelData.getUint8(pixelIndex + 3);
    return alphaValue == 0; // 투명하면 true
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    canvas.drawImage(image, Offset.zero, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mp3',
    );
  }
}
