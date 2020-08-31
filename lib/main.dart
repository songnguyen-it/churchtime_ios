import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong/latlong.dart' as D;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primaryColor: Color(0xffFED721)),
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  FirebaseDatabase _firebaseDatabase = FirebaseDatabase.instance;
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  var startTimeDead = new DateTime.utc(2020, DateTime.august, 26);
  double radiusFindChurch = 3;
  List<bool> valueOfCheckboxTime = [false, false, false];
  List<dynamic> valueOfCheckboxNotifications = [
    false,
    false,
    false,
    false,
    false,
    false,
    false
  ];
  List<LatLng> listLatLong = [];
  static Position position;
  final D.Distance distance = D.Distance();
  double distanceCount = 0.0;
  double destinationLat;
  double destinationLong;
  Set<Circle> circles = {};

  // route direction
  GoogleMapController mapController;
  Map<MarkerId, Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = "AIzaSyAHIbHnEINmL5vLjrK9rKXK-TlREpcpGUU";
  Map<dynamic, dynamic> churchesData = {};

  // local notifications
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void getLocation() async {
    position = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _kGooglePlex = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 14.4746,
      );

      circles.add(Circle(
        circleId: CircleId("churchtime_mobile"),
        fillColor: Colors.redAccent.withOpacity(0.5),
        strokeColor: Colors.redAccent,
        strokeWidth: 1,
        center: LatLng(position.latitude, position.longitude),
        radius: radiusFindChurch * 1000,
      ));

      _firebaseDatabase.reference().child('Churches').once().then((value) {
        if (value != null) {
          final data = value.value as Map;
          for (var val in data.values) {
            double lat = double.parse(val['church_latitude']);
            double long = double.parse(val['church_longitude']);
            var km = distance.as(
                D.LengthUnit.Kilometer,
                D.LatLng(position.latitude, position.longitude),
                D.LatLng(lat, long));

            if (km < radiusFindChurch) {
              if (km < distanceCount || distanceCount == 0) {
                distanceCount = km;
                setState(() {
                  markers = {};

                  /// origin marker
                  _addMarker(LatLng(position.latitude, position.longitude),
                      "origin", BitmapDescriptor.defaultMarker);

                  /// destination marker
                  _addMarker(LatLng(lat, long), "destination",
                      BitmapDescriptor.defaultMarkerWithHue(90));
                  destinationLat = lat;
                  destinationLong = long;
                });
              }
            }
          }
        }
      });
    });
  }

  static CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(position.latitude, position.longitude),
    zoom: 14.4746,
  );

  void updateCheckbox(int index) {
    valueOfCheckboxTime = [false, false, false];
    valueOfCheckboxTime[index] = !valueOfCheckboxTime[index];
  }

  _addMarker(LatLng position, String id, BitmapDescriptor descriptor) {
    setState(() {
      MarkerId markerId = MarkerId(id);
      Marker marker =
          Marker(markerId: markerId, icon: descriptor, position: position);
      markers[markerId] = marker;
    });
  }

  _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
        width: 4,
        polylineId: id,
        color: Colors.red,
        points: polylineCoordinates);
    polylines[id] = polyline;

    setState(() {});
  }

  _getPolyline() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleAPiKey,
      PointLatLng(position.latitude, position.longitude),
      PointLatLng(destinationLat, destinationLong),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates = [];
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        setState(() {});
      });
    }
    _addPolyLine();
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
  }

  void updateCircle() {
    setState(() {
      circles = {};
      circles.add(Circle(
        circleId: CircleId("churchtime_mobile"),
        fillColor: Colors.redAccent.withOpacity(0.5),
        strokeColor: Colors.redAccent,
        strokeWidth: 1,
        center: LatLng(position.latitude, position.longitude),
        radius: radiusFindChurch * 1000,
      ));
      // _firebaseDatabase.reference().child('Churches').once().then((value) {
      if (churchesData.length != 0) {
        // final data = value.value as Map;
        for (var val in churchesData.values) {
          double lat = double.parse(val['church_latitude']);
          double long = double.parse(val['church_longitude']);
          var km = distance.as(
              D.LengthUnit.Kilometer,
              D.LatLng(position.latitude, position.longitude),
              D.LatLng(lat, long));
          print(km);
          print(radiusFindChurch);
          if (km < radiusFindChurch) {
            if (km < distanceCount || distanceCount == 0) {
              print("smaller churchRadius");
              distanceCount = km;
              setState(() {
                markers = {};

                /// origin marker
                _addMarker(LatLng(position.latitude, position.longitude),
                    "origin", BitmapDescriptor.defaultMarker);

                /// destination marker
                _addMarker(LatLng(lat, long), "destination",
                    BitmapDescriptor.defaultMarkerWithHue(90));
                destinationLat = lat;
                destinationLong = long;
                print(markers);
              });
            }
          }
          if (km > radiusFindChurch) {
            distanceCount = km;
            setState(() {
              markers = {};
            });
          }
        }
      }
      // });
    });
  }

  Future<void> scheduleNotification(
      {int hour,
      int minute,
      String churchname,
      String id,
      int indexId,
      Time time,
      String dateOfWeek,
      String realTime}) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'id$indexId', 'name$indexId', 'description$indexId');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    // print(dateOfWeek);

    if (dateOfWeek == "monday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Monday,
          time,
          platformChannelSpecifics);
    }
    if (dateOfWeek == "tuesday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Tuesday,
          time,
          platformChannelSpecifics);
    }
    if (dateOfWeek == "wednesday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Wednesday,
          time,
          platformChannelSpecifics);
    }

    if (dateOfWeek == "thursday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Thursday,
          time,
          platformChannelSpecifics);
    }
    if (dateOfWeek == "friday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Friday,
          time,
          platformChannelSpecifics);
    }
    if (dateOfWeek == "saturday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Saturday,
          time,
          platformChannelSpecifics);
    }
    if (dateOfWeek == "sunday") {
      await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
          indexId,
          '$churchname',
          'Giờ mở cửa lúc $realTime',
          Day.Sunday,
          time,
          platformChannelSpecifics);
    }
  }

  Future onSelectNotification(String payload) async {
    setState(() {
      getLocation();
    });
  }

  @override
  void initState() {
    super.initState();

    var now = DateTime.now();
    int deltaDistance = now.difference(startTimeDead).inDays;

    if(deltaDistance < 30) {
      var android = AndroidInitializationSettings('app_icon');
      var ios = IOSInitializationSettings();
      var setting = InitializationSettings(android, ios);
      flutterLocalNotificationsPlugin.initialize(setting,
          onSelectNotification: onSelectNotification);
      _firebaseDatabase.reference().child('Churches').once().then((value) {
        if (value.value != null) {
          setState(() {
            churchesData = value.value;
          });
        }
      });


      // SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);

      getLocation();
      _firebaseDatabase.reference().child('Mobile/radius').once().then((data) {
        if (data.value != null) {
          setState(() {
            radiusFindChurch = double.parse(data.value);
          });
        }
      });

      _firebaseDatabase
          .reference()
          .child('Mobile/notification')
          .once()
          .then((data) {
        if (data.value != null) {
          setState(() {
            valueOfCheckboxTime = [false, false, false];
            valueOfCheckboxTime[data.value] = true;
          });
        }
      });
      _firebaseDatabase
          .reference()
          .child('Mobile/list_time_notification')
          .once()
          .then((data) {
        if (data.value != null) {
          setState(() {
            valueOfCheckboxNotifications = jsonDecode(data.value);
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 5000), () {
        _firebaseDatabase.reference().child('Churches').once().then((data) {
          if (data.value != null) {
            Map<dynamic, dynamic> churches = data.value;
            int indexId = 0;
            for (var v in churches.values) {
              String nameOfChurch = v['church_name'];
              String churchId = v['id'];

              print(nameOfChurch);
              Map<dynamic, dynamic> timeExtended = jsonDecode(
                  v['time_extended']);

              for (var k in timeExtended.keys) {
                if (k == 'monday' && valueOfCheckboxNotifications[0] == true ||
                    k == 'tuesday' && valueOfCheckboxNotifications[1] == true ||
                    k == 'wednesday' &&
                        valueOfCheckboxNotifications[2] == true ||
                    k == 'thursday' &&
                        valueOfCheckboxNotifications[3] == true ||
                    k == 'friday' && valueOfCheckboxNotifications[4] == true ||
                    k == 'saturday' &&
                        valueOfCheckboxNotifications[5] == true ||
                    k == 'sunday' && valueOfCheckboxNotifications[6] == true) {
                  String removeLastColon = (timeExtended[k] as String)
                      .substring(0, (timeExtended[k] as String).length - 2);

                  var timeInDateOfWeek = removeLastColon.split(",");
                  print(timeInDateOfWeek);

                  for (var splitHourMinute in timeInDateOfWeek) {
                    print("realtime: $splitHourMinute");
                    int hours = int.parse(splitHourMinute.split(":")[0]);
                    int minute = int.parse(splitHourMinute.split(":")[1]);
                    int timeMinus = 0;
                    for (var index = 0;
                    index < valueOfCheckboxTime.length;
                    index++) {
                      if (valueOfCheckboxTime[index] == true) {
                        if (index == 0) {
                          timeMinus = 15;
                        }
                        if (index == 1) {
                          timeMinus = 30;
                        }
                        if (index == 2) {
                          timeMinus = 60;
                        }
                      }
                    }
                    if (minute > timeMinus) {
                      minute = minute - timeMinus;
                    } else {
                      hours = hours - 1;
                      minute = minute + (60 - timeMinus);
                      if (minute >= 60) {
                        hours += 1;
                        minute = minute - 60;
                      }
                    }

                    print(timeMinus);
                    print("$hours:$minute");

                    indexId++;
                    scheduleNotification(
                        hour: hours,
                        minute: minute,
                        churchname: nameOfChurch,
                        id: churchId,
                        time: Time(hours, minute, 00),
                        indexId: indexId,
                        dateOfWeek: k,
                        realTime: splitHourMinute);
                  }
                }
              }
            }
          }
        });
      });
    }


    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: ListTile(
              title: Text(message['notification']['title']),
              subtitle: Text(message['notification']['body']),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('Ok'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
      },
    );
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, state) {
          return AlertDialog(
            title: Text(
              'CÀI ĐẶT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(
                    "Thời gian thông báo",
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SingleChildScrollView(
                    child: Row(
                      children: [
                        Column(
                          children: <Widget>[
                            Text(
                              "15p",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                _firebaseDatabase
                                    .reference()
                                    .child('Mobile')
                                    .update({
                                  'notification': 0 //yes I know.
                                });
                                state(() {
                                  updateCheckbox(0);
                                });
                              },
                              value: valueOfCheckboxTime[0],
                            )
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Text(
                              "30p",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                _firebaseDatabase
                                    .reference()
                                    .child('Mobile')
                                    .update({
                                  'notification': 1 //yes I know.
                                });
                                state(() {
                                  updateCheckbox(1);
                                });
                              },
                              value: valueOfCheckboxTime[1],
                            )
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Text(
                              "60p",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                _firebaseDatabase
                                    .reference()
                                    .child('Mobile')
                                    .update({
                                  'notification': 2 //yes I know.
                                });
                                state(() {
                                  updateCheckbox(2);
                                });
                              },
                              value: valueOfCheckboxTime[2],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Bán kính tìm nhà thờ: ${radiusFindChurch.toStringAsFixed(1)} km',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    activeColor: Color(0xffFED721),
                    value: radiusFindChurch,
                    max: 30.0,
                    min: 1.0,
                    onChanged: (v) {
                      _firebaseDatabase.reference().child('Mobile').update({
                        'radius': v.toStringAsFixed(1) //yes I know.
                      });

                      state(() {
                        radiusFindChurch = v;
                      });
                      updateCircle();
                    },
                  ),
                  Text(
                    "Bật thông báo",
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(
                              "T2",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[0] =
                                      !valueOfCheckboxNotifications[0];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[0],
                            )
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "T3",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[1] =
                                      !valueOfCheckboxNotifications[1];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[1],
                            )
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "T4",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[2] =
                                      !valueOfCheckboxNotifications[2];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[2],
                            )
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "T5",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[3] =
                                      !valueOfCheckboxNotifications[3];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[3],
                            )
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "T6",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[4] =
                                      !valueOfCheckboxNotifications[4];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[4],
                            )
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "T7",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[5] =
                                      !valueOfCheckboxNotifications[5];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[5],
                            )
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "CN",
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            Checkbox(
                              activeColor: Color(0xffFED721),
                              onChanged: (v) {
                                state(() {
                                  valueOfCheckboxNotifications[6] =
                                      !valueOfCheckboxNotifications[6];
                                  var jsonListTimeNotification =
                                      jsonEncode(valueOfCheckboxNotifications);
                                  _firebaseDatabase
                                      .reference()
                                      .child('Mobile')
                                      .update({
                                    'list_time_notification':
                                        jsonListTimeNotification
                                  });
                                });
                              },
                              value: valueOfCheckboxNotifications[6],
                            )
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(
                  'Thoát',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "ChurchTime",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(icon: Icon(Icons.settings), onPressed: _showMyDialog)
        ],
      ),
      body: position == null
          ? Offstage()
          : GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _kGooglePlex,
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              circles: circles,
              markers: Set<Marker>.of(markers.values),
              polylines: Set<Polyline>.of(polylines.values)),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            backgroundColor: Color(0xffFED721),
            onPressed: () {
              _getPolyline();
            },
            tooltip: "Chỉ đường",
            child: Icon(Icons.directions),
          ),
          SizedBox(width: 15,),
          FloatingActionButton(
            tooltip: "Tải lại địa điểm",
            backgroundColor: Color(0xffFED721),
            onPressed: () {
              getLocation();
            },
            child: Icon(Icons.refresh),
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // backup 25/08/2020
    );
  }
}
