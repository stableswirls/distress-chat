import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:static_map/static_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class ChatScreen extends StatefulWidget {
  static String id = 'chat_screen';
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late User loggedInUser;
  final messageTextController = TextEditingController();
  String messageText = '';

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _sendMessage() async {
    messageTextController.clear();
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await _firestore.collection('messages').add({
        'text': messageText.isEmpty ? "Shared location" : messageText,
        'sender': loggedInUser.email,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
    } catch (e) {
      print('Error sending message: $e');
      // Handle the error appropriately
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('⚡️Chat')),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MessagesStream(),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.lightBlueAccent, width: 2.0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: messageTextController,
                      onChanged: (value) {
                        messageText = value;
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 20.0),
                        hintText: 'Type your message here...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _sendMessage,
                    child: Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              backgroundColor: Colors.lightBlueAccent,
            ),
          );
        }
        final messages = snapshot.data!.docs;
        List<MessageBubble> messageBubbles = [];
        for (var message in messages) {
          final messageText = message['text'];
          final messageSender = message['sender'];
          final currentUser = FirebaseAuth.instance.currentUser?.email;
          final latitude = message['latitude'];
          final longitude = message['longitude'];

          final messageBubble = MessageBubble(
            sender: messageSender,
            text: messageText,
            isMe: currentUser == messageSender,
            latitude: latitude,
            longitude: longitude,
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
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble(
      {required this.sender,
      required this.text,
      required this.isMe,
      this.latitude,
      this.longitude});

  final String sender;
  final String text;
  final bool isMe;
  final double? latitude;
  final double? longitude;

  void _launchMaps() async {
    if (latitude != null && longitude != null) {
      final url = 'https://maps.google.com/?q=$latitude,$longitude';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    }
  }

  String _getStaticMapUrl() {
    if (latitude != null && longitude != null) {
      final zoom = 16;
      final tileSize = 256; // OSM tile size in pixels

      // Calculate the x and y tile numbers
      final x = (longitude! + 180.0) / 360.0 * (1 << zoom);
      final y = (1.0 -
              log(tan(latitude! * pi / 180.0) +
                      1.0 / cos(latitude! * pi / 180.0)) /
                  pi) /
          2.0 *
          (1 << zoom);

      // Get the integer tile coordinates
      final tileX = x.floor();
      final tileY = y.floor();

      // To center, calculate the pixel offset within the tile
      final offsetX = ((x - tileX) * tileSize).round();
      final offsetY = ((y - tileY) * tileSize).round();

      // We use this to ensure that we center the tile around the coordinates
      // You can adjust the size of the image based on your needs by adding more tile offsets if needed.
      return 'https://a.tile.openstreetmap.org/$zoom/$tileX/$tileY.png?offset_x=$offsetX&offset_y=$offsetY';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sender,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.black54,
            ),
          ),
          Material(
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
            color: isMe ? Colors.lightBlueAccent : Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black54,
                      fontSize: 15.0,
                    ),
                  ),
                  if (latitude != null && longitude != null)
                    Column(
                      children: [
                        // TextButton(
                        //   onPressed: _launchMaps,
                        //   child: Text(
                        //     'https://maps.google.com/?q=$latitude,$longitude',
                        //     style: TextStyle(
                        //       color: isMe ? Colors.white : Colors.blue,
                        //       decoration: TextDecoration.underline,
                        //     ),
                        //   ),
                        // ),
                        GestureDetector(
                          onTap: _launchMaps,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25.0),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      _getStaticMapUrl(),
                                    ),
                                  ),
                                ),
                                // child: Image.network(
                                //   _getStaticMapUrl(),
                                //   fit: BoxFit.cover,
                                //   loadingBuilder: (BuildContext context,
                                //       Widget child,
                                //       ImageChunkEvent? loadingProgress) {
                                //     if (loadingProgress == null) return child;
                                //     return Center(
                                //       child: CircularProgressIndicator(
                                //         value: loadingProgress
                                //                     .expectedTotalBytes !=
                                //                 null
                                //             ? loadingProgress
                                //                     .cumulativeBytesLoaded /
                                //                 loadingProgress
                                //                     .expectedTotalBytes!
                                //             : null,
                                //       ),
                                //     );
                                //   },
                                // ),
                              ),
                              Icon(
                                Icons.pin_drop,
                                color: Colors.red,
                              )
                            ],
                          ),
                        ),
                        // osm.OSMViewer(
                        //   controller: osm.SimpleMapController(
                        //     initPosition: osm.GeoPoint(
                        //         longitude: longitude!, latitude: latitude!),
                        //     markerHome: osm.MarkerIcon(
                        //       icon: Icon(
                        //         Icons.pin_drop,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
