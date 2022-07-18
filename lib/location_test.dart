import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

import 'location_details.dart';

const kGoogleApiKey = "";
GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);

void main() {
  runApp(MaterialApp(
    title: "PlaceZ",
    home: Home(),
    debugShowCheckedModeBanner: false,
  ));
}

class Home extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<Home> {
  final homeScaffoldKey = GlobalKey<ScaffoldState>();
  late GoogleMapController mapController;
  List<PlacesSearchResult> places = [];
  bool isLoading = false;
  String? errorMessage;
  Set<Marker> markers = {};

  @override
  Widget build(BuildContext context) {
    Widget expandedChild;
    if (isLoading) {
      expandedChild = Center(child: CircularProgressIndicator(value: null));
    } else if (errorMessage != null) {
      expandedChild = Center(
        child: Text(errorMessage ?? ''),
      );
    } else {
      expandedChild = buildPlacesList();
    }

    return Scaffold(
        key: homeScaffoldKey,
        appBar: AppBar(
          title: const Text("PlaceZ"),
          actions: <Widget>[
            isLoading
                ? IconButton(
                    icon: Icon(Icons.timer),
                    onPressed: () {},
                  )
                : IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () {
                      refresh();
                    },
                  ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                _handlePressButton();
              },
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Container(
              child: SizedBox(
                  height: 200.0,
                  child: GoogleMap(
                    markers: {},
                    onMapCreated: _onMapCreated,
                    initialCameraPosition:
                        CameraPosition(target: LatLng(0.0, 0.0)),
                  )),
            ),
            Expanded(child: expandedChild)
          ],
        ));
  }

  void refresh() async {
    final center = await getUserLocation();

    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: center == null ? LatLng(0, 0) : center, zoom: 15.0)));
    getNearbyPlaces(center!);
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    refresh();
  }

  Future<LatLng?> getUserLocation() async {
    Map<String, double>? currentLocation = <String, double>{};
    await Geolocator.requestPermission();
    final location = await Geolocator.getCurrentPosition();
    try {
      //currentLocation = (await location.getLocation()) as Map<String, double>;
      final lat = location.latitude;
      final lng = location.longitude;
      final center = LatLng(lat, lng);
      return center;
    } on Exception {
      currentLocation = null;
      return null;
    }
  }

  void getNearbyPlaces(LatLng center) async {
    setState(() {
      this.isLoading = true;
      this.errorMessage = null;
    });

    final location = Location(lat: center.latitude, lng: center.longitude);
    final result = await _places.searchNearbyWithRadius(location, 2500);

    setState(() {
      this.isLoading = false;
      if (result.status == "OK") {
        this.places = result.results;
        result.results.forEach((f) {
          final markerOptions = Marker(
              markerId: MarkerId('dda'),
              position:
                  LatLng(f.geometry!.location.lat, f.geometry!.location.lng),
              infoWindow: InfoWindow(title: "${f.name}" + "${f.types.first}"));
          markers.add(markerOptions);
        });
        setState(() {});
      } else {
        this.errorMessage = result.errorMessage;
      }
    });
  }

  void onError(PlacesAutocompleteResponse response) {
    homeScaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(response.errorMessage ?? '')),
    );
  }

  Future<void> _handlePressButton() async {
    try {
      final center = null;
      Prediction? p = await PlacesAutocomplete.show(
          context: context,
          types: [],
          strictbounds: center == null ? false : true,
          apiKey: kGoogleApiKey,
          onError: onError,
          mode: Mode.overlay,
          logo: Text('data'),
          components: <Component>[],
          language: "en",
          location: center == null
              ? null
              : Location(lng: center.longitude, lat: center.latitude),
          radius: center == null ? null : 10000);
      print(p?.description);
      print(p?.terms);
      print(p?.types);

      showDetailPlace(p!.placeId!);
    } catch (e) {
      return;
    }
  }

  Future<Null> showDetailPlace(String placeId) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailWidget(placeId)),
    );
  }

  ListView buildPlacesList() {
    final placesWidget = places.map((f) {
      List<Widget> list = [
        Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text(
            f.name,
            style: Theme.of(context).textTheme.subtitle1,
          ),
        )
      ];
      if (f.formattedAddress != null) {
        list.add(Padding(
          padding: EdgeInsets.only(bottom: 2.0),
          child: Text(
            f.formattedAddress ?? '',
            style: Theme.of(context).textTheme.subtitle1,
          ),
        ));
      }

      if (f.vicinity != null) {
        list.add(Padding(
          padding: EdgeInsets.only(bottom: 2.0),
          child: Text(
            f.vicinity ?? '',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ));
      }

      list.add(Padding(
        padding: EdgeInsets.only(bottom: 2.0),
        child: Text(
          f.types.first,
          style: Theme.of(context).textTheme.caption,
        ),
      ));

      return Padding(
        padding: EdgeInsets.only(top: 4.0, bottom: 4.0, left: 8.0, right: 8.0),
        child: Card(
          child: InkWell(
            onTap: () {
              print(f.geometry?.location.lat);
              //showDetailPlace(f.placeId);
            },
            highlightColor: Colors.lightBlueAccent,
            splashColor: Colors.red,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: list,
              ),
            ),
          ),
        ),
      );
    }).toList();

    return ListView(shrinkWrap: true, children: placesWidget);
  }
}
