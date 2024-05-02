import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _localZoom = false;

  TextEditingController sdpController = TextEditingController();
  final _localRender = new RTCVideoRenderer();
  final _remoteRender = new RTCVideoRenderer();
  RTCPeerConnection? _rtcPeerConnection;
  MediaStream? _localStream;
  bool _offer = false;

  @override
  void initState() {
    initRenders();
    _createPeerConnection().then((pc) {
      _rtcPeerConnection = pc;
    });

    super.initState();
    // TODO: implement initState
  }

  @override
  dispose() {
    sdpController.dispose();
    _localRender.dispose();
    _remoteRender.dispose();
    super.dispose();
  }

  Future initRenders() async {
    await _localRender.initialize();
    await _remoteRender.initialize();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "sdpSemantics": "plan-b",
      "bundlePolicy": 'max-compat',
      "rtcpMuxPolicy": 'negotiate',
      'iceServers': [
        {"url": "stun:stun.stunprotocol.org"}
      ]
    };

    final Map<String, dynamic> offerSdpConstrains = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": []
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstrains);
    pc.addStream(_localStream!);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          "candidate": e.candidate.toString(),
          "sdpMid": e.sdpMid.toString(),
          "sdpMlineIndex": e.sdpMLineIndex,
        }));
      }
    };
    pc.onIceConnectionState = (e) {
      print(e);
    };
    pc.onAddStream = (stream) {
      print("addstream $stream");
      _remoteRender.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        'facingMode': 'user',
      },
    };
    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    _localRender.srcObject = stream;
    return stream;
  }

  _createOffer() async {
    RTCSessionDescription description =
        await _rtcPeerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(jsonEncode(session));
    _offer = true;
    _rtcPeerConnection!.setLocalDescription(description);
  }

  _createAnswer() async {
    RTCSessionDescription description =
        await _rtcPeerConnection!.createAnswer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(jsonEncode(session));
    _rtcPeerConnection!.setLocalDescription(description);
  }

  _setRemoteDesc() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode("$jsonString");
    String sdp = write(session, null);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());
    await _rtcPeerConnection!.setRemoteDescription(description);
  }

  _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode("$jsonString");
    print(session["candidate"]);
    dynamic candidate = RTCIceCandidate(
        session["candidate"], session["sdpMid"], session["sdpMlineIndex"]);
    await _rtcPeerConnection!.addCandidate(candidate);
  }

  SizedBox videoRenders() => SizedBox(
        // height: 200,
        // width: 300,
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  color: Colors.black,
                  height: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).size.height / 4,
                  width: MediaQuery.of(context).size.width,
                  key: Key("local"),
                  child:
                      RTCVideoView(!_localZoom ? _remoteRender : _localRender),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onDoubleTap: () {
                  setState(() {
                    _localZoom = !_localZoom;
                  });
                },
                child: Container(
                  color: Colors.black,
                  height: 150,
                  width: 150,
                  key: Key("remote"),
                  child:
                      RTCVideoView(!_localZoom ? _localRender : _remoteRender),
                ),
              ),
            ),
          ],
        ),
      );

  Row offerAndAnswerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(onPressed: _createOffer, child: Text("Call")),
          ElevatedButton(onPressed: _createAnswer, child: Text("Accept Call"))
        ],
      );

  Container sdpCondidateTF() => Container(
        width: 200,
        height: 60,
        child: TextFormField(
          controller: sdpController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          maxLength: TextField.noMaxLength,
        ),
      );

  Row sdpCondidatesButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
              onPressed: _setRemoteDesc, child: Text("Set Remote Desc.")),
          ElevatedButton(
              onPressed: _setCandidate, child: Text("Add candidite")),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          // width: 300,
          // height: 300,
          child: Column(
            children: [
              // RTCVideoView(_localRender),
              videoRenders(),
              Container(
                height: MediaQuery.of(context).size.height / 4,
                child: Column(
                  children: [
                    offerAndAnswerButtons(),
                    sdpCondidateTF(),
                    sdpCondidatesButtons(),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
