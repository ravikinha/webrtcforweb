import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void sendMessage(text) {
  String messageText = text.trim();
  if (messageText.isNotEmpty) {
    FirebaseFirestore.instance.collection('messages').add({
      'text': messageText,
      'timestamp': DateTime.now(),
    });
  }
}

class ChatRoom extends StatelessWidget {
  final TextEditingController _messageController = TextEditingController();
  void _deleteMessage(DocumentSnapshot message) {
    FirebaseFirestore.instance.collection('messages').doc(message.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    return ListTile(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: message['text']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Message copied')),
                        );
                      },
                      title: Text(message['text']),
                      subtitle: GestureDetector(
                          onLongPress: () {
                            _deleteMessage(message);
                          },
                          child: Text(message['timestamp'].toString())),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    sendMessage(_messageController.text);
                    _messageController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
