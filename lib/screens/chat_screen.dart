import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';


final _firestore = Firestore.instance;
final ScrollController listScrollController = ScrollController();
var messages;
String chatId;

class ChatScreen extends StatefulWidget {
  static const String id = 'chat_screen';
  final String displayId;
  final String displayImage;
  final String currentUserId;
  final String name;

  ChatScreen({@required this.displayId, @required this.displayImage, @required this.currentUserId, this.name});
  @override
  _ChatScreenState createState() => _ChatScreenState(displayId: displayId, displayImage: displayImage, currentUserId: currentUserId, name: name);
}

class _ChatScreenState extends State<ChatScreen> {

  final String displayId;
  final String displayImage;
  final String currentUserId;
  final String name;

  _ChatScreenState({@required this.displayId, @required this.displayImage, @required this.currentUserId, this.name});

  final messageTextController = TextEditingController();
  String messageText;
  SharedPreferences prefs;
  var image;
  String imageUrl;
  int type;




  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    chatId = '';
    readLocal();
  }
  readLocal() async {
    if (currentUserId.hashCode <= displayId.hashCode) {
      chatId = '$currentUserId-$displayId';
    } else {
      chatId = '$displayId-$currentUserId';
    }

    Firestore.instance.collection('users').document(currentUserId).updateData({'chattingWith': displayId});

    setState(() {});
  }

  Future getImage() async{
    image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if(image!=null)
    {
      setState(() {

      });
    }
    String file = DateTime.now().millisecondsSinceEpoch.toString();
    StorageReference reference =FirebaseStorage.instance.ref().child(file);
    StorageUploadTask uploadTask =reference.putFile(image);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    storageTaskSnapshot.ref.getDownloadURL().then((value){
      imageUrl = value;
      setState(() {
        onSendMsg(imageUrl, 1);
      });
    }, onError: (err){
      Fluttertoast.showToast(msg: 'Please upload jpg/jpeg/png only');
    });
  }
  void onSendMsg(String content, int type)
  {
    if(content.trim()!= '') {
      messageTextController.clear();
      var documentReference = _firestore.collection(
          'messages').document(chatId)
          .collection(chatId)
          .document(DateTime
          .now()
          .millisecondsSinceEpoch
          .toString());
      _firestore.runTransaction((transaction) async {
        await transaction.set(documentReference, {
          'idFrom': currentUserId,
          'idTo': displayId,
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch
              .toString(),
          'content': content,
          'type': type,

        });
      });
    }
    else
    {
      Fluttertoast.showToast(msg: 'Nothing to send');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          color: Color(0xFF162447),
        ),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.close, color:  Color(0xFF162447),),
              onPressed: () {
                Navigator.pop(context);
              }),
        ],
        title: Text('$name', style: TextStyle(color:  Color(0xFF162447)),),
        backgroundColor: Colors.white,

      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MessagesStream(currentUserId: currentUserId,),
            Container(
              decoration: kMessageContainerDecoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: messageTextController,
                      onChanged: (value) {
                        messageText = value;
                      },
                      decoration: kMessageTextFieldDecoration,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 1.0),
                    child: IconButton(
                     icon: Icon(Icons.image, color:  Color(0xFF162447), size: 35.0,),

                     onPressed: () {
                       messageText = imageUrl;
                       getImage();
                     },
                    ),
                  ),
                  FlatButton(
                    onPressed: () {
                      onSendMsg(messageTextController.text, 0);
                    },
                    child: Text(
                      'Send',
                      style: kSendButtonTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesStream extends StatelessWidget {
  String currentUserId;
  MessagesStream({this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('messages').document(chatId).collection(chatId).orderBy('timestamp', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              backgroundColor: Color(0xFF162447),
            ),
          );
        }
        final messages = snapshot.data.documents;

       List<MessageBubble> messageBubbles = [];
       for(var message in messages){
         final messageText = message.data['content'];
        final messageTime = message.data['timestamp'];
        final sender = message.data['idFrom'];
        final messageType = message.data['type'];

        final messageBubble = MessageBubble(
        time: messageTime,
        text: messageText,
          type: messageType,
          isMe: currentUserId == sender,

        );
         messageBubbles.add(messageBubble);
      }
        return Expanded(
          child: ListView(
            reverse: true,
            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
            children: messageBubbles,
          ),
        );
        }
    );
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble({this.time, this.text, this.isMe, this.type});

  final String time;
  final String text;
  final bool isMe;
  final int type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[

          Text(
            DateFormat('dd MMM kk:mm').format(DateTime.fromMicrosecondsSinceEpoch(int.parse(time))),
            style: TextStyle(
              fontSize: 12.0,
              color: Color(0xFF162447).withOpacity(0.5),
            ),
          ),
          type ==0
          ? Material(
            borderRadius: isMe
                ? BorderRadius.only(
                topLeft: Radius.circular(30.0),
                bottomLeft: Radius.circular(30.0),
                bottomRight: Radius.circular(30.0))
                : BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
              topRight: Radius.circular(30.0),
            ),
            elevation: 5.0,
            color: isMe ? Color(0xFF162447).withOpacity(0.8) : Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Color(0xFF162447).withOpacity(0.8),
                  fontSize: 15.0,
                ),
              ),
            ),
          )
          : Container(
            child: Material(
              child: CachedNetworkImage(
                imageUrl: text,
                width: 200.0,
                height: 200.0,

              ),
            ),
          )

        ],
      ),
    );
  }
}