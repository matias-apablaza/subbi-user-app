import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:multi_image_picker/multi_image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:subbi/apis/remote_config_api.dart';
import 'package:subbi/models/auction/auction.dart';
import 'package:subbi/models/auction/category.dart';
import 'package:subbi/models/profile/chat.dart';
import 'package:subbi/models/profile/profile.dart';
import 'package:subbi/models/profile/profile_rating.dart';
import 'package:subbi/others/error_logger.dart';
import 'package:subbi/models/auction/bid.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ServerApi {
  static ServerApi _singleton = new ServerApi._internal();

  ServerApi._internal();
  static IO.Socket socket;

  factory ServerApi.instance() {
    host = host ?? RemoteConfigApi.instance().serverURL;

    //host = "http://10.0.2.2:3000";
    return _singleton;
  }

  static String host;
  static int signUpStatusCode = 404;

  String sessionCookie;

  void onSocketEvent(String event, dynamic Function(dynamic) handler) {
    if (socket == null) {
      socket = IO.io('http://subbi.herokuapp.com/auction', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      socket.connect();
    }

    socket.on(event, handler);
  }

  void emitSocketEvent(String event, [dynamic data]) {
    if (socket == null) {
      socket = IO.io('http://subbi.herokuapp.com/auction', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      socket.connect();
    }
    socket.emit(event, data);
  }

  /* -------------------------------------------------------------------------------------------------------------------------------
                                                         ACCOUNT MANAGEMENT
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
    Performs a login and returns if user exists or should sign up
  ---------------------------------------------------------------------------- */

  Future<bool> signIn({
    @required String userToken,
  }) async {
    var res = await http.post(
      host + '/login',
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'idToken': userToken,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 404)
      ErrorLogger.log(
        context: "Loging in",
        error: res.reasonPhrase,
      );

    sessionCookie = res.headers['set-cookie'];

    return res.statusCode != signUpStatusCode;
  }

  /* ----------------------------------------------------------------------------
    Creates a new user, sends personal data to the server
  ---------------------------------------------------------------------------- */

  Future<void> signUp({
    @required String name,
    @required String surname,
    @required DocType docType,
    @required String docId,
    @required String phone,
    @required PhoneType phoneType,
    @required String country,
    @required String state,
    @required String city,
    @required String address,
    @required String addressNumber,
    @required String zip,
  }) async {
    var res = await http.post(
      host + '/register',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: jsonEncode({
        "name": name,
        "last_name": surname,
        "document_type": docType.toString().split('.')[1].toLowerCase(),
        "document": docId,
        "telephone_type": phoneType.toString().split('.')[1].toLowerCase(),
        "telephone": phone,
        "country": country,
        "province": state,
        "location": city,
        "zip": zip,
        "street": address,
        "street_number": addressNumber,
      }),
    );

    if (res.statusCode != 201) {
      ErrorLogger.log(
        context: "Signing up",
        error: res.reasonPhrase,
      );
    }
  }

  /* ----------------------------------------------------------------------------
    Deletes a user account
  ---------------------------------------------------------------------------- */

  Future<void> deleteAccount({
    @required String uid,
  }) async {
    var res = await http.delete(
      host + '/user/' + uid,
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: "Deleting account",
        error: res.reasonPhrase,
      );
    }
  }

  /* -------------------------------------------------------------------------------------------------------------------------------
                                                      PROFILE
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
    Get the public information of a profile
  ---------------------------------------------------------------------------- */

  Future<Profile> getProfile({
    @required String ofUid,
  }) async {
    var res = await http.get(
      host + '/user/' + ofUid,
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Getting a profile public information',
        error: res.reasonPhrase,
      );
    }

    var json = jsonDecode(res.body);

    return new Profile(
      profileUid: json["id"],
      name: json["name"] + " " + json["last_name"],
      location: json["location"],
      profilePicURL:
          "https://forum.processmaker.com/download/file.php?avatar=93310_1550846185.png",
      user: null,
    );
  }

  /* ----------------------------------------------------------------------------
   Check wether this user is following a profile
  ---------------------------------------------------------------------------- */

  Future<bool> isFollowing({
    @required String followerUid,
    @required String followedUid,
  }) async {
    var res = await http.get(
      host + '/user/following?followed_id=$followedUid',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Checking following relation',
        error: res.reasonPhrase,
      );
    }

    return jsonDecode(res.body)["following"];
  }

  /* ----------------------------------------------------------------------------
   Follow a profile
  ---------------------------------------------------------------------------- */

  Future<void> followProfile({
    @required String followedUid,
    @required bool follow,
  }) async {
    var res;

    if (follow) {
      res = await http.post(
        host + '/user/following?followed_id=$followedUid',
        headers: {
          'Content-Type': 'application/json',
          'Cookie': sessionCookie,
        },
      );
    } else {
      res = await http.delete(
        host + '/user/following?followed_id=$followedUid',
        headers: {
          'Content-Type': 'application/json',
          'Cookie': sessionCookie,
        },
      );
    }

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Following a user',
        error: res.reasonPhrase,
      );
    }
  }

  /* ----------------------------------------------------------------------------
   Rate a profile
  ---------------------------------------------------------------------------- */

  Future<void> rateProfile({
    @required String ratedUid,
    @required double rate,
    @required String comment,
  }) async {
    var res = await http.post(
      host + '/user/$ratedUid/rating',
      headers: {
        'Cookie': sessionCookie,
      },
      body: {
        "comment": comment,
        "rating": rate.toString(),
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Rating a profile',
        error: res.reasonPhrase,
      );
    }
  }

  /* ----------------------------------------------------------------------------
   Get the ratings of a profile
  ---------------------------------------------------------------------------- */

  Future<List<ProfileRating>> getRatings({
    @required String ofUid,
  }) async {
    var res = await http.get(
      host + '/user/$ofUid/rating',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons.map(
      (json) {
        return ProfileRating(
          raterUid: json["from_id"],
          ratedUid: json["to_id"],
          rate: double.parse(json["rating"]),
          comment: json["comment"],
          date: DateTime.parse(json["date"]),
        );
      },
    ).toList();
  }

/* -------------------------------------------------------------------------------------------------------------------------------
                                                      CATEGORY
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
   Get all categories
  ---------------------------------------------------------------------------- */

  Future<List<Category>> getCategories() async {
    var res = await http.get(
      host + '/lot/categories',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Getting categories',
        error: res.reasonPhrase,
      );
    }

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons.map(
      (json) {
        return Category(
          name: json['name'],
          description: json['description'],
          iconName: json['iconid'],
        );
      },
    ).toList();
  }

  /* -------------------------------------------------------------------------------------------------------------------------------
                                                      AUCTION
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
   Get the auctions of a profile
  ---------------------------------------------------------------------------- */

  Future<List<Auction>> getProfileAuctions({
    @required String ofUid,
  }) async {
    var res = await http.get(
      host + '/auction/byUser/' + ofUid,
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Getting auctions posted by a user',
        error: res.reasonPhrase,
      );
    }

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons
        .map(
          (json) => Auction(
              auctionId: json["lot_id"],
              title: json["name"],
              description: json["description"],
              deadLine: DateTime.parse(json["deadline"]),
              category: json["category"],
              initialPrice: double.parse(json["initial_price"]),
              quantity: json["quantity"],
              ownerUid: ofUid,
              state: json["state"],
              photosIds: (json["photos_ids"]).cast<int>()),
        )
        .toList();
  }

  /* ----------------------------------------------------------------------------
   Get the auctions on which a user is participating
  ---------------------------------------------------------------------------- */

  Future<List<Auction>> getParticipatingAuctions() async {
    var res = await http.get(
      host + '/auction/bidding/',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Getting user participating auctions',
        error: res.reasonPhrase,
      );
    }

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons
        .map(
          (json) => Auction(
              auctionId: json["lot_id"],
              title: json["name"],
              description: json["description"],
              deadLine: DateTime.parse(json["deadline"]),
              category: json["category"],
              initialPrice: double.parse(json["initial_price"]),
              quantity: json["quantity"],
              ownerUid: json["owner_id"],
              state: json["state"],
              photosIds: (json["photos_ids"]).cast<int>()),
        )
        .toList();
  }

  /* ----------------------------------------------------------------------------
   Get a specific set of auctions (CREATION_DATE, POPULARITY, DEADLINE)
  ---------------------------------------------------------------------------- */

  Future<List<Auction>> getAuctionsBySort({
    @required String category,
    @required int limit,
    @required int offset,
    @required AuctionSort sort,
  }) async {
    var sortString = sort
        .toString()
        .toLowerCase()
        .split('.')[1]; // Conversion from enum to string

    String path = category == null
        ? '/auction/list?sort=$sortString&limit=$limit&offset=$offset'
        : '/auction/list?sort=$sortString&limit=$limit&offset=$offset&category=$category';

    var res = await http.get(
      host + path,
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: 'Getting $sort auctions',
        error: res.reasonPhrase,
      );
    }

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons.map(
      (json) {
        return Auction(
          auctionId: json["lot_id"],
          title: json["name"],
          description: json["description"],
          deadLine: DateTime.parse(json["deadline"]),
          category: json["category"],
          initialPrice: double.parse(json["initial_price"]),
          quantity: json["quantity"],
          ownerUid: json["owner_id"],
          state: json["state"],
          photosIds: (json["photos_ids"]).cast<int>(),
        );
      },
    ).toList();
  }

  /* -------------------------------------------------------------------------------------------------------------------------------
                                                      LOTS
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
   Post a new lot
  ---------------------------------------------------------------------------- */

  Future<int> postLot({
    @required String title,
    @required String category,
    @required String description,
    @required double initialPrice,
    @required int quantity,
    @required List<int> imgIds,
  }) async {
    var res = await http.post(
      host + '/lot',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: jsonEncode({
        "name": title,
        "category": category,
        "description": description,
        "initial_price": initialPrice.toString(),
        "quantity": quantity,
        "lot_photos": imgIds
      }),
    );

    if (res.statusCode != 201) {
      ErrorLogger.log(
        context: "Send lot",
        error: res.reasonPhrase,
      );
    }

    return 0;
  }

  /* -------------------------------------------------------------------------------------------------------------------------------
                                                      BIDS
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
   Get the current bids of an auction
  ---------------------------------------------------------------------------- */

  Future<List<Bid>> getCurrentBids({
    @required int auctionId,
    @required offset,
    @required limit,
  }) async {
    var res = await http.get(
      host +
          '/bid/byAuction/' +
          auctionId.toString() +
          "?limit=$limit&offset=$offset",
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: "Getting current bids of an auction",
        error: res.reasonPhrase,
      );
    }

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons
        .map(
          (json) => Bid(
            auctionId: auctionId,
            placerUid: json["user_id"],
            amount: double.parse(json["amount"]),
            date: DateTime.parse(json["time"]),
          ),
        )
        .toList();
  }

  /* ----------------------------------------------------------------------------
   Get a socket for bids stream
  ---------------------------------------------------------------------------- */

  Socket getBidsSocket({@required int auctionId}) {
    var socket = IO.io(
      'http://subbi.herokuapp.com/auction',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      },
    );

    socket.connect();
    socket.emit('subscribe', auctionId);

    return socket;
  }

  /* -------------------------------------------------------------------------------------------------------------------------------
                                                      MESSAGES
  ------------------------------------------------------------------------------------------------------------------------------- */

  /* ----------------------------------------------------------------------------
   Get the current bids of an auction
  ---------------------------------------------------------------------------- */

  Future<List<Message>> getCurrentMessages({
    @required String withUid,
  }) async {
    var res = await http.get(
      host + '/chat/' + withUid + '?limit=10',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
    );

    if (res.statusCode != 200) {
      ErrorLogger.log(
        context: "Getting current messages with a profile",
        error: res.reasonPhrase,
      );
    }

    var jsons = jsonDecode(res.body) as List<dynamic>;

    return jsons
        .map(
          (json) => Message(
            fromUid: json["from_id"],
            toUid: json["to_id"],
            text: json["msg"],
            date: DateTime.parse(json["date"]),
          ),
        )
        .toList();
  }

  /* ----------------------------------------------------------------------------
   Get a socket for messages stream
  ---------------------------------------------------------------------------- */

  Socket getMessageSocket() {
    var session = sessionCookie.split('session=')[1].split(';')[0];

    var _messageSocket = IO.io(
      'http://subbi.herokuapp.com/chat',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'cookie': session,
        },
      },
    );

    _messageSocket.connect();

    return _messageSocket;
  }

  /* ----------------------------------------------------------------------------
   Send a new message
  ---------------------------------------------------------------------------- */

  Future<void> sendMessage({
    @required String message,
    @required String toUid,
  }) async {
    var res = await http.post(
      host + '/chat/' + toUid,
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: jsonEncode({
        "msg": message,
      }),
    );

    if (res.statusCode != 201) {
      ErrorLogger.log(
        context: "Sending message",
        error: res.reasonPhrase,
      );
    }
  }

  /* ----------------------------------------------------------------------------
   Post a new bid
  ---------------------------------------------------------------------------- */

  Future<void> postBid({
    @required int auctionId,
    @required double amount,
  }) async {
    var res = await http.post(
      host + '/auction/' + auctionId.toString() + '/bid',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: jsonEncode({
        "auc_id": auctionId,
        "amount": amount,
      }),
    );

    if (res.statusCode != 201) {
      ErrorLogger.log(
        context: "Posting a bid",
        error: res.reasonPhrase,
      );
    }
  }

  /* ----------------------------------------------------------------------------
   Post a new picture
  ---------------------------------------------------------------------------- */

  Future<int> postPhoto(Asset image) async {
    ByteData byteData = await image.getByteData();

    // string to uri
    Uri uri = Uri.parse(host + '/photo');

    // create multipart request
    http.MultipartRequest request = http.MultipartRequest("POST", uri);

    List<int> imageData = byteData.buffer.asUint8List();

    http.MultipartFile multipartFile = http.MultipartFile.fromBytes(
      'image',
      imageData,
      filename: image.name,
      contentType: MediaType("image", "jpg"),
    );

    // add file to multipart
    request.headers['Cookie'] = sessionCookie;
    request.files.add(multipartFile);

    var response = await request.send();
    if (response.statusCode != 201) {
      ErrorLogger.log(
        context: "Uploading photo",
        error: response.reasonPhrase,
      );
    }
    var resp = await http.Response.fromStream(response);

    return jsonDecode(resp.body)["id"];
  }

  /* ----------------------------------------------------------------------------
   Post a new picture ID
  ---------------------------------------------------------------------------- */

  Future<void> postPhotoID(int photoId, int lotId) async {
    var res = await http.post(
      host + '/lot/photo',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: jsonEncode({
        "photo_id": photoId,
        "lot_id": lotId,
      }),
    );

    if (res.statusCode != 201) {
      ErrorLogger.log(
        context: "Posting photo ID",
        error: res.reasonPhrase,
      );
    }
  }
}

/* -------------------------------------------------------------------------------------------------------------------------------
                                                      MERCADOPAGO
  ------------------------------------------------------------------------------------------------------------------------------- */

enum DocType { DNI, CI, PASSPORT }

enum PhoneType { MOBILE, LANDLINE }

enum AuctionSort { CREATION_DATE, POPULARITY, DEADLINE }
