import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

import 'chatroom/chatRoom.dart';
import 'firebase_options.dart';

// ...

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const webSocket(title: 'Flutter Demo Home Page'),
      // home: ChatRoom(),
    );
  }
}

class webSocket extends StatefulWidget {
  const webSocket({super.key, required this.title});

  final String title;

  @override
  State<webSocket> createState() => _webSocketState();
}

class _webSocketState extends State<webSocket> {
  bool _showChat = false;
  bool _localZoom = false;
  bool _isMicMuted = false;
  bool _isVideoOff = false;

  TextEditingController sdpController = TextEditingController();
  final _localRender = RTCVideoRenderer();
  final _remoteRender = RTCVideoRenderer();
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
    int a = 0;
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          "candidate": e.candidate.toString(),
          "sdpMid": e.sdpMid.toString(),
          "sdpMlineIndex": e.sdpMLineIndex,
        }));
        if (a == 0)
          sendMessage(json.encode({
            "candidate": e.candidate.toString(),
            "sdpMid": e.sdpMid.toString(),
            "sdpMlineIndex": e.sdpMLineIndex,
          }));
      }
      print(a++);
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
      "audio": !_isMicMuted,
      "video": !_isVideoOff
          ? {
              'facingMode': 'user',
            }
          : false,
    };
    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    _localRender.srcObject = stream;
    return stream;
  }

  _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    _updateMediaStream();
  }

  _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _updateMediaStream();
  }

  _updateMediaStream() async {
    await _localStream?.dispose();
    _localStream = await _getUserMedia();
    _localStream!.getTracks().forEach((track) {
      if (track.kind == 'audio') {
        track.enabled = !_isMicMuted;
      }
      if (track.kind == 'video') {
        track.enabled = !_isVideoOff;
      }
    });
  }

  _createOffer() async {
    RTCSessionDescription description =
        await _rtcPeerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(jsonEncode(session));
    sendMessage(jsonEncode(session));
    _offer = true;
    _rtcPeerConnection!.setLocalDescription(description);
  }

  _createAnswer() async {
    RTCSessionDescription description =
        await _rtcPeerConnection!.createAnswer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(jsonEncode(session));
    sendMessage(jsonEncode(session));
    _rtcPeerConnection!.setLocalDescription(description);
  }

  _setRemoteDesc() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode("$jsonString");
    String sdp = write(session, null);
    RTCSessionDescription description =
        RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
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
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  color: Colors.black,
                  height: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).size.height / 3,
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
      resizeToAvoidBottomInset: false,
      floatingActionButton: FloatingActionButton(onPressed: () {
        setState(() {
          _showChat = !_showChat;
        });
      }),
      body: Center(
        child: Stack(
          children: [
            Container(
              child: Column(
                children: [
                  videoRenders(),
                  Container(
                    height: MediaQuery.of(context).size.height / 3,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton(
                              onPressed: _toggleMic,
                              child:
                                  Text(_isMicMuted ? 'Unmute Mic' : 'Mute Mic'),
                            ),
                            ElevatedButton(
                              onPressed: _toggleVideo,
                              child: Text(_isVideoOff
                                  ? 'Turn Video On'
                                  : 'Turn Video Off'),
                            ),
                          ],
                        ),
                        offerAndAnswerButtons(),
                        sdpCondidateTF(),
                        sdpCondidatesButtons(),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Positioned(
                child: AnimatedContainer(
              duration: Duration(seconds: 1),
              height: _showChat ? MediaQuery.of(context).size.height / 2 : 0,
              child: ChatRoom(),
            ))
          ],
        ),
      ),
    );
  }
}
