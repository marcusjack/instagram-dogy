import 'package:chewie/chewie.dart';
import 'package:chewie/src/chewie_player.dart';
import 'package:dodogy_challange/widgets/progress.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:cached_video_player/cached_video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animator/animator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dodogy_challange/models/user.dart';
import 'package:dodogy_challange/pages/activity_feed.dart';
import 'package:dodogy_challange/pages/comments.dart';
import 'package:dodogy_challange/homyz.dart';
import 'package:dodogy_challange/widgets/custom_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class Post extends StatefulWidget {
  final bool myPhoto;
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  final dynamic likes;
  final bool addDivider;
  final BuildContext masterContext;
  final Timestamp timestamp;

  Post(
      {this.myPhoto = false,
      this.postId,
      this.ownerId,
      this.username,
      this.location,
      this.description,
      this.mediaUrl,
      this.likes,
      this.timestamp,
      this.addDivider = false,
      this.masterContext})
      : super(key: ValueKey(postId));

  factory Post.fromDocument(DocumentSnapshot doc,
      {bool addDivider = false,
      BuildContext masterContext,
      bool myPhoto = false}) {
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      description: doc['description'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
      timestamp: doc["timestamp"],
      addDivider: addDivider,
      masterContext: masterContext,
      myPhoto: myPhoto,
    );
  }

  int getLikeCount(likes) {
    // if no likes, return 0
    if (likes == null) {
      return 0;
    }
    int count = 0;
    // if the key is explicitly set to true, add a like
    likes.values.forEach((val) {
      if (val == true) {
        count += 1;
      }
    });
    return count;
  }

  @override
  _PostState createState() => _PostState(
        postId: this.postId,
        ownerId: this.ownerId,
        username: this.username,
        location: this.location,
        description: this.description,
        mediaUrl: this.mediaUrl,
        likes: this.likes,
        likeCount: getLikeCount(this.likes),
        timestamp: this.timestamp,
      );
}

class _PostState extends State<Post> {
  final String currentUserId = currentUser?.id;
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  final Timestamp timestamp;
  bool isVisible = true;
  bool showHeart = false;
  bool isLiked;
  int likeCount;
  Map likes;

  _PostState(
      {this.postId,
      this.ownerId,
      this.username,
      this.location,
      this.description,
      this.mediaUrl,
      this.likes,
      this.likeCount,
      this.timestamp});

  buildPostHeader(BuildContext context) {
    return FutureBuilder(
      future: usersRef.document(ownerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 72,
          );
        }
        User user = User.fromDocument(snapshot.data);
        bool isPostOwner = currentUserId == ownerId;
        return GestureDetector(
            onTap: () => showProfile(context, profileId: user.id),
            child: ListTile(
              leading: CachedNetworkImage(
                  imageUrl: user.photoUrl ??
                      "https://www.asjfkfhdgihdknjskdjfeid.com",
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                        backgroundColor: Colors.grey,
                        backgroundImage: imageProvider,
                      ),
                  errorWidget: (context, url, error) => Padding(
                      padding: EdgeInsets.all(12), //heret
                      child: Icon(
                        CupertinoIcons.person_solid,
                        color: Colors.black,
                      ))),
              title: widget.myPhoto
                  ? Text(
                      timeago.format(timestamp.toDate()),
                      style: TextStyle(color: Colors.grey, fontSize: 12.5),
                    )
                  : Text(
                      user.username,
                      style: TextStyle(
                          color: Color.fromRGBO(24, 115, 172, 1),
                          fontWeight: FontWeight.w400,
                          fontSize: 20),
                    ),
              subtitle: widget.myPhoto
                  ? null
                  : Text(timeago.format(timestamp.toDate())),
              trailing: isPostOwner
                  ? IconButton(
                      onPressed: () => handleDeletePost(context),
                      icon: Icon(CupertinoIcons.delete_solid),
                    )
                  : Text(''),
            ));
      },
    );
  }

  handleDeletePost(BuildContext parentContext) {
    return showDialog(
        context: parentContext,
        builder: (context) {
          return CupertinoAlertDialog(
            title: Text("Remove this post?"),
            actions: <Widget>[
              FlatButton(
                  onPressed: () {
                    Navigator.pop(context);
                    deletePost();
                    if (widget.masterContext != null) {
                      Navigator.pop(widget.masterContext);
                    }
                  },
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  )),
              FlatButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel')),
            ],
          );
        });
  }

  // Note: To delete post, ownerId and currentUserId must be equal, so they can be used interchangeably
  deletePost() async {
    // delete post itself
    postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .get()
        .then((doc) {
      if (doc.exists) {
        doc.reference.delete();
      }
    });
    // delete uploaded image for thep ost
    try {
      storageRef.child("post_$postId.jpg").delete();
    } catch (e) {
      print("This was not a photo");
    }

    try {
      storageRef.child("post_$postId.mp4").delete();
    } catch (e) {
      print("This was not a vid");
    }
//
//    try{
//      storageRef.child("post_$postId.gif").delete();
//    }
//    catch(e){
//      print("This was not a gif");
//    }

    // then delete all activity feed notifications
    QuerySnapshot activityFeedSnapshot = await activityFeedRef
        .document(ownerId)
        .collection("feedItems")
        .where('postId', isEqualTo: postId)
        .getDocuments();
    activityFeedSnapshot.documents.forEach((doc) {
      if (doc.exists) {
        doc.reference.delete();
      }
    });
    // then delete all comments
    QuerySnapshot commentsSnapshot = await commentsRef
        .document(postId)
        .collection('comments')
        .getDocuments();
    commentsSnapshot.documents.forEach((doc) {
      if (doc.exists) {
        doc.reference.delete();
      }
    });
    setState(() {
      isVisible = false;
    });
  }

  handleLikePost() {
    bool _isLiked = likes[currentUserId] == true;

    if (_isLiked) {
      postsRef
          .document(ownerId)
          .collection('userPosts')
          .document(postId)
          .updateData({'likes.$currentUserId': false});
      removeLikeFromActivityFeed();
      setState(() {
        likeCount -= 1;
        isLiked = false;
        likes[currentUserId] = false;
      });
    } else if (!_isLiked) {
      postsRef
          .document(ownerId)
          .collection('userPosts')
          .document(postId)
          .updateData({'likes.$currentUserId': true});
      addLikeToActivityFeed();
      setState(() {
        likeCount += 1;
        isLiked = true;
        likes[currentUserId] = true;

        showHeart = true;
      });
      Timer(Duration(milliseconds: 500), () {
        setState(() {
          showHeart = false;
        });
      });
    }
  }

  addLikeToActivityFeed() {
    // add a notification to the postOwner's activity feed only if comment made by OTHER user (to avoid getting notification for our own like)
    bool isNotPostOwner = currentUserId != ownerId;
    if (isNotPostOwner) {
      activityFeedRef
          .document(ownerId)
          .collection("feedItems")
          .document(postId)
          .setData({
        "type": "like",
        "username": currentUser.username,
        "userId": currentUser.id,
        "userProfileImg": currentUser.photoUrl,
        "postId": postId,
        "mediaUrl": mediaUrl,
        "timestamp": DateTime.now(),
      });
    }
  }

  removeLikeFromActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;
    if (isNotPostOwner) {
      activityFeedRef
          .document(ownerId)
          .collection("feedItems")
          .document(postId)
          .get()
          .then((doc) {
        if (doc.exists) {
          doc.reference.delete();
        }
      });
    }
  }

  buildPostImage() {
    bool vid = mediaUrl.toLowerCase().contains(".mp4");
    final v = Theme(
      data: ThemeData.light().copyWith(
        platform: TargetPlatform.iOS,
      ),
      child:VideoItem(mediaUrl));
    return GestureDetector(
      onDoubleTap: handleLikePost,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          vid ? v : cachedNetworkImage(mediaUrl),
          showHeart
              ? Animator(
                  duration: Duration(milliseconds: 300),
                  tween: Tween(begin: 0.8, end: 1.4),
                  curve: Curves.elasticOut,
                  cycles: 0,
                  builder: (anim) => Transform.scale(
                    scale: anim.value,
                    child: Icon(
                      CupertinoIcons.heart,
                      size: 80.0,
                      color: Colors.pink,
                    ),
                  ),
                )
              : Text(""),
        ],
      ),
    );
  }

  buildPostFooter() {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(top: 40.0, left: 20.0)),
            GestureDetector(
              onTap: handleLikePost,
              child: Icon(
                isLiked ? CupertinoIcons.heart_solid : CupertinoIcons.heart,
                size: 28.0,
                color: Colors.pink,
              ),
            ),
            Padding(padding: EdgeInsets.only(right: 20.0)),
            GestureDetector(
              onTap: () => showComments(
                context,
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl,
              ),
              child: Icon(
                CupertinoIcons.conversation_bubble,
                size: 34.0,
                color: Color.fromRGBO(24, 115, 172, 1),
              ),
            ),
          ],
        ),
        Visibility(
            visible: description.length > 0,
            child: Row(
              children: <Widget>[
                Container(
                  child: Text(
                    description,
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                  margin: EdgeInsets.only(left: 20.0),
                )
              ],
            )),
        Visibility(
            visible: location.length > 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  margin: EdgeInsets.only(left: 20.0),
                  child: Text(
                    location,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            )),
        Row(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                "$likeCount likes",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w300,
                    fontSize: 18),
              ),
            )
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    isLiked = (likes[currentUserId] == true);

    return Visibility(
        visible: isVisible,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            buildPostHeader(context),
            buildPostImage(),
            buildPostFooter(),
            (widget.addDivider)
                ? Padding(
                    padding: const EdgeInsets.only(
                        right: 75.0, left: 75, top: 10, bottom: 10),
                    child: Divider(
                      height: 8.0,
                      color: Color.fromRGBO(24, 115, 172, .6),
                      thickness: .15,
                    ),
                  )
                : Text(""),
          ],
        ));
  }
}

showComments(BuildContext context,
    {String postId, String ownerId, String mediaUrl}) {
  Navigator.push(context, MaterialPageRoute(builder: (context) {
    return Comments(
      postId: postId,
      postOwnerId: ownerId,
      postMediaUrl: mediaUrl,
    );
  }));
}

class VideoItem extends StatefulWidget {
  final String url;

  VideoItem(this.url);

  @override
  _VideoItemState createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  ChewieController _chewieController;
  CachedVideoPlayerController _controller;
  Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();

    _controller = CachedVideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {}); //when your thumbnail will show.
      });
    _initializeVideoPlayerFuture = _controller.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _controller,
      aspectRatio: 3 / 2,
      autoPlay: true,
      looping: true,
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.lightGreen,
      ),
      placeholder: Container(
        color: Colors.grey,
      ),

      showControlsOnInitialize: true
    );
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _chewieController.dispose();
    _controller.pause();
    _controller.seekTo(Duration(seconds: 0));
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the VideoPlayerController has finished initialization, use
          // the data it provides to limit the aspect ratio of the VideoPlayer.
          _controller.setLooping(true);
          return GestureDetector(
              child: Chewie(
                controller: _chewieController,
              ),


              onTap: () {
                if (_controller.value.isPlaying){
                  _chewieController.pause();
                }
                else{
                  _chewieController.play();
                }

              });
        } else {
          return Center(child: circularProgress());
        }
      },
    );
  }
}
