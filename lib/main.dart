import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

void main() {
  runApp(BusRouteFinderApp());
}

class BusRouteFinderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Route Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: BusRouteHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BusStop {
  final String name;
  final LatLng position;
  final String routeId;
  final String routeName;
  final int stopOrder;

  BusStop({
    required this.name,
    required this.position,
    required this.routeId,
    required this.routeName,
    required this.stopOrder,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusStop &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          routeId == other.routeId;

  @override
  int get hashCode => name.hashCode ^ routeId.hashCode;
}

class RouteSegment {
  final BusStop startStop;
  final BusStop endStop;
  final String routeName;
  final String routeId;
  final List<BusStop> pathStops;
  final int travelTime;
  final double distance;

  RouteSegment({
    required this.startStop,
    required this.endStop,
    required this.routeName,
    required this.routeId,
    required this.pathStops,
    required this.travelTime,
    required this.distance,
  });
}

class RouteResult {
  final List<RouteSegment> segments;
  final List<BusStop> allStops;
  final String routeDescription;
  final int totalWalkingTime;
  final int totalBusTime;
  final int totalWaitingTime;
  final double totalWalkingDistance;
  final double totalBusDistance;
  final String instructions;
  final String startTime;
  final String endTime;
  final int totalTime;
  final BusStop? transferStop;
  final bool hasTransfer;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteResult({
    required this.segments,
    required this.allStops,
    required this.routeDescription,
    required this.totalWalkingTime,
    required this.totalBusTime,
    required this.totalWaitingTime,
    required this.totalWalkingDistance,
    required this.totalBusDistance,
    required this.instructions,
    required this.startTime,
    required this.endTime,
    required this.totalTime,
    this.transferStop,
    required this.hasTransfer,
    required this.startLocation,
    required this.endLocation,
  });
}

class BusRouteHomePage extends StatefulWidget {
  @override
  _BusRouteHomePageState createState() => _BusRouteHomePageState();
}

class _BusRouteHomePageState extends State<BusRouteHomePage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  
  LatLng? _currentLocation;
  LatLng? _fromLocation;
  LatLng? _destination;
  List<BusStop> _busStops = [];
  List<RouteResult> _routeResults = [];
  bool _isLoading = false;
  bool _showRouteResults = false;
  bool _useCurrentLocation = true;
  int _selectedRouteIndex = 0;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Search suggestions
  List<BusStop> _fromSuggestions = [];
  List<BusStop> _toSuggestions = [];
  bool _showFromSuggestions = false;
  bool _showToSuggestions = false;

  // Route optimization parameters
  final double _maxWalkingDistance = 2000; // 2km max walking distance
  final double _walkingSpeed = 75; // meters per minute
  final int _averageWaitTime = 8; // minutes
  final int _transferPenalty = 10; // additional minutes for transfers
  final double _busSpeed = 400; // meters per minute (average with stops)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _initializeBusStops();
    _getCurrentLocation();
  }

  void _initializeBusStops() {
    _busStops = [
      // Route 1: Lagankhel-Naya Buspark
      BusStop(name: "Gongabu Buspark", position: LatLng(27.735138, 85.308082), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 1),
      BusStop(name: "Gongabu Chowk", position: LatLng(27.7349404, 85.3146154), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 2),
      BusStop(name: "Samakhusi", position: LatLng(27.735021, 85.316453), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 3),
      BusStop(name: "Talim Kendra", position: LatLng(27.736980, 85.323375), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 4),
      BusStop(name: "Basundhara", position: LatLng(27.742141, 85.332581), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 6),
      BusStop(name: "Teaching Hospital", position: LatLng(27.734582, 85.330886), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 9),
      BusStop(name: "Panipokhari", position: LatLng(27.729587, 85.324845), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 10),
      BusStop(name: "Lazimpat", position: LatLng(27.724606, 85.322329), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 11),
      BusStop(name: "Jamal", position: LatLng(27.707002, 85.314218), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 13),
      BusStop(name: "Tripureshwor", position: LatLng(27.69371, 85.31416), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 16),
      BusStop(name: "Pulchowk", position: LatLng(27.680773, 85.317357), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 20),
      BusStop(name: "Jawalakhel", position: LatLng(27.67292, 85.31371), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 21),
      BusStop(name: "Lagankhel", position: LatLng(27.666915, 85.323038), routeId: "1", routeName: "Lagankhel-Naya Buspark", stopOrder: 23),

      // Route 2: Ratnapark-Bhaktapur
      BusStop(name: "Ratnapark", position: LatLng(27.7065, 85.3137), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 1),
      BusStop(name: "Bhotahity", position: LatLng(27.7045, 85.3125), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 2),
      BusStop(name: "Bagbazar", position: LatLng(27.7089, 85.3098), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 3),
      BusStop(name: "Dillibazar", position: LatLng(27.7156, 85.3201), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 4),
      BusStop(name: "Gaushala", position: LatLng(27.7201, 85.3289), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 5),
      BusStop(name: "Chabahil", position: LatLng(27.7267, 85.3445), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 6),
      BusStop(name: "Jorpati", position: LatLng(27.7398, 85.3612), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 7),
      BusStop(name: "Mulpani", position: LatLng(27.7456, 85.3789), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 8),
      BusStop(name: "Thimi", position: LatLng(27.6789, 85.3901), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 9),
      BusStop(name: "Bhaktapur", position: LatLng(27.6710, 85.4298), routeId: "2", routeName: "Ratnapark-Bhaktapur", stopOrder: 10),

      // Route 3: RNAC-Dhungin
      BusStop(name: "RNAC", position: LatLng(27.7132, 85.3240), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 1),
      BusStop(name: "Jamal", position: LatLng(27.707002, 85.314218), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 2),
      BusStop(name: "Tripureshwor", position: LatLng(27.69371, 85.31416), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 5),
      BusStop(name: "Pulchowk", position: LatLng(27.680773, 85.317357), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 9),
      BusStop(name: "Jawalakhel", position: LatLng(27.67292, 85.31371), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 10),
      BusStop(name: "Lagankhel", position: LatLng(27.666915, 85.323038), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 12),
      BusStop(name: "Gwarko", position: LatLng(27.6732666, 85.3135375), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 15),
      BusStop(name: "Imadol", position: LatLng(27.6849132, 85.2986117), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 18),
      BusStop(name: "Dhungin", position: LatLng(27.6726494, 85.3132419), routeId: "3", routeName: "RNAC-Dhungin", stopOrder: 29),

      // Route 4: Ring Road Express
      BusStop(name: "Kalanki", position: LatLng(27.6936, 85.2795), routeId: "4", routeName: "Ring Road Express", stopOrder: 1),
      BusStop(name: "Kalimati", position: LatLng(27.6998, 85.2889), routeId: "4", routeName: "Ring Road Express", stopOrder: 2),
      BusStop(name: "Teku", position: LatLng(27.6945, 85.3067), routeId: "4", routeName: "Ring Road Express", stopOrder: 3),
      BusStop(name: "Tripureshwor", position: LatLng(27.69371, 85.31416), routeId: "4", routeName: "Ring Road Express", stopOrder: 4),
      BusStop(name: "Thapathali", position: LatLng(27.69065, 85.31738), routeId: "4", routeName: "Ring Road Express", stopOrder: 5),
      BusStop(name: "Baneshwor", position: LatLng(27.6895, 85.3456), routeId: "4", routeName: "Ring Road Express", stopOrder: 6),
      BusStop(name: "Tinkune", position: LatLng(27.6789, 85.3567), routeId: "4", routeName: "Ring Road Express", stopOrder: 7),
      BusStop(name: "Koteshwor", position: LatLng(27.6678, 85.3445), routeId: "4", routeName: "Ring Road Express", stopOrder: 8),
      BusStop(name: "Balkumari", position: LatLng(27.6534, 85.3198), routeId: "4", routeName: "Ring Road Express", stopOrder: 9),
      BusStop(name: "Ekantakuna", position: LatLng(27.6723, 85.2987), routeId: "4", routeName: "Ring Road Express", stopOrder: 10),

      // Route 5: Budhanilkantha Express
      BusStop(name: "Budhanilkantha", position: LatLng(27.7623, 85.3698), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 1),
      BusStop(name: "Tokha", position: LatLng(27.7456, 85.3567), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 2),
      BusStop(name: "Maharajgunj", position: LatLng(27.7345, 85.3456), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 3),
      BusStop(name: "Chakrapath", position: LatLng(27.7298, 85.3389), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 4),
      BusStop(name: "Bansbari", position: LatLng(27.7234, 85.3301), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 5),
      BusStop(name: "Durbarmarg", position: LatLng(27.7089, 85.3178), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 6),
      BusStop(name: "Ratnapark", position: LatLng(27.7065, 85.3137), routeId: "5", routeName: "Budhanilkantha Express", stopOrder: 7),

      // Route 6: Nepal Yatayat
      BusStop(name: "Old Buspark", position: LatLng(27.7056, 85.3089), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 1),
      BusStop(name: "Asan", position: LatLng(27.7045, 85.3098), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 2),
      BusStop(name: "Indrachowk", position: LatLng(27.7034, 85.3067), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 3),
      BusStop(name: "Basantapur", position: LatLng(27.7023, 85.3045), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 4),
      BusStop(name: "Bhotebahal", position: LatLng(27.6998, 85.3023), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 5),
      BusStop(name: "Sundhara", position: LatLng(27.6967, 85.3134), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 6),
      BusStop(name: "Babarmahal", position: LatLng(27.6934, 85.3178), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 7),
      BusStop(name: "Singhadurbar", position: LatLng(27.6912, 85.3198), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 8),
      BusStop(name: "Baneshwor", position: LatLng(27.6895, 85.3456), routeId: "6", routeName: "Nepal Yatayat", stopOrder: 9),

      // Additional Route 7: Kirtipur-Ratnapark
      BusStop(name: "Kirtipur", position: LatLng(27.6789, 85.2798), routeId: "7", routeName: "Kirtipur-Ratnapark", stopOrder: 1),
      BusStop(name: "Naikap", position: LatLng(27.6834, 85.2856), routeId: "7", routeName: "Kirtipur-Ratnapark", stopOrder: 2),
      BusStop(name: "Kalanki", position: LatLng(27.6936, 85.2795), routeId: "7", routeName: "Kirtipur-Ratnapark", stopOrder: 3),
      BusStop(name: "Kalimati", position: LatLng(27.6998, 85.2889), routeId: "7", routeName: "Kirtipur-Ratnapark", stopOrder: 4),
      BusStop(name: "Teku", position: LatLng(27.6945, 85.3067), routeId: "7", routeName: "Kirtipur-Ratnapark", stopOrder: 5),
      BusStop(name: "Ratnapark", position: LatLng(27.7065, 85.3137), routeId: "7", routeName: "Kirtipur-Ratnapark", stopOrder: 6),

      // Additional Route 8: Patan-Swayambhu
      BusStop(name: "Mangal Bazar", position: LatLng(27.6731, 85.3242), routeId: "8", routeName: "Patan-Swayambhu", stopOrder: 1),
      BusStop(name: "Lagankhel", position: LatLng(27.666915, 85.323038), routeId: "8", routeName: "Patan-Swayambhu", stopOrder: 2),
      BusStop(name: "Pulchowk", position: LatLng(27.680773, 85.317357), routeId: "8", routeName: "Patan-Swayambhu", stopOrder: 3),
      BusStop(name: "Thapathali", position: LatLng(27.69065, 85.31738), routeId: "8", routeName: "Patan-Swayambhu", stopOrder: 4),
      BusStop(name: "Ratnapark", position: LatLng(27.7065, 85.3137), routeId: "8", routeName: "Patan-Swayambhu", stopOrder: 5),
      BusStop(name: "Swayambhu", position: LatLng(27.7145, 85.2913), routeId: "8", routeName: "Patan-Swayambhu", stopOrder: 6),
    ];
  }

  Future<void> _getCurrentLocation() async {
    try {
      var status = await Permission.location.request();
      if (status.isGranted) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          if (_useCurrentLocation) {
            _fromLocation = _currentLocation;
            _fromController.text = "Your Location";
          }
        });
        if (_currentLocation != null) {
          _mapController.move(_currentLocation!, 13.0);
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      // Fallback to Kathmandu center
      setState(() {
        _currentLocation = LatLng(27.7172, 85.3240);
        if (_useCurrentLocation) {
          _fromLocation = _currentLocation;
          _fromController.text = "Your Location";
        }
      });
      _mapController.move(_currentLocation!, 13.0);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  void _searchFromSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _fromSuggestions = [];
        _showFromSuggestions = false;
      });
      return;
    }

    setState(() {
      _fromSuggestions = _busStops
          .where((stop) => stop.name.toLowerCase().contains(query.toLowerCase()))
          .toSet()
          .take(5)
          .toList();
      _showFromSuggestions = _fromSuggestions.isNotEmpty;
    });
  }

  void _searchToSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _toSuggestions = [];
        _showToSuggestions = false;
      });
      return;
    }

    setState(() {
      _toSuggestions = _busStops
          .where((stop) => stop.name.toLowerCase().contains(query.toLowerCase()))
          .toSet()
          .take(5)
          .toList();
      _showToSuggestions = _toSuggestions.isNotEmpty;
    });
  }

  // Enhanced route finding algorithm that covers all routes
  List<RouteResult> _findAllOptimalRoutes(String destinationQuery) {
    if (_fromLocation == null) return [];
    
    List<RouteResult> allRoutes = [];
    DateTime now = DateTime.now();
    
    // Find all destination stops that match the query
    List<BusStop> destinationStops = _busStops
        .where((stop) => stop.name.toLowerCase().contains(destinationQuery.toLowerCase()))
        .toList();
    
    if (destinationStops.isEmpty) return [];
    
    // For each destination stop, find all possible routes
    for (BusStop destStop in destinationStops) {
      // Direct routes (single bus line)
      allRoutes.addAll(_findDirectRoutes(destStop, now));
      
      // Transfer routes (connecting through other stops)
      allRoutes.addAll(_findTransferRoutes(destStop, now));
    }
    
    // Remove duplicates and sort by efficiency
    allRoutes = _removeDuplicateRoutes(allRoutes);
    allRoutes.sort((a, b) => _calculateRouteScore(a).compareTo(_calculateRouteScore(b)));
    
    return allRoutes.take(5).toList(); // Return top 5 routes
  }

  List<RouteResult> _findDirectRoutes(BusStop destStop, DateTime now) {
    List<RouteResult> directRoutes = [];
    
    // Get all stops on the same route as destination
    List<BusStop> routeStops = _busStops
        .where((stop) => stop.routeId == destStop.routeId)
        .toList()
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
    
    // Find nearest boarding stop
    BusStop? bestBoardingStop;
    double minWalkDistance = double.infinity;
    
    for (BusStop stop in routeStops) {
      if (stop.stopOrder < destStop.stopOrder) {
        double walkDistance = _calculateDistance(_fromLocation!, stop.position);
        if (walkDistance <= _maxWalkingDistance && walkDistance < minWalkDistance) {
          minWalkDistance = walkDistance;
          bestBoardingStop = stop;
        }
      }
    }
    
    if (bestBoardingStop != null) {
      List<BusStop> pathStops = routeStops
          .where((stop) => 
              stop.stopOrder >= bestBoardingStop!.stopOrder && 
              stop.stopOrder <= destStop.stopOrder)
          .toList();
      
      RouteSegment segment = RouteSegment(
        startStop: bestBoardingStop,
        endStop: destStop,
        routeName: destStop.routeName,
        routeId: destStop.routeId,
        pathStops: pathStops,
        travelTime: _calculateBusTime(bestBoardingStop, destStop),
        distance: _calculateRouteDistance(pathStops),
      );
      
      directRoutes.add(_createRouteResult(
        segments: [segment],
        startLocation: _fromLocation!,
        endLocation: destStop.position,
        now: now,
        hasTransfer: false,
      ));
    }
    
    return directRoutes;
  }

  List<RouteResult> _findTransferRoutes(BusStop destStop, DateTime now) {
    List<RouteResult> transferRoutes = [];
    
    // Get all routes that don't contain the destination
    Set<String> otherRouteIds = _busStops
        .map((stop) => stop.routeId)
        .where((id) => id != destStop.routeId)
        .toSet();
    
    for (String routeId in otherRouteIds) {
      List<BusStop> firstRouteStops = _busStops
          .where((stop) => stop.routeId == routeId)
          .toList()
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
      
      // Find nearest boarding stop on first route
      BusStop? firstBoardingStop;
      double minWalkToFirst = double.infinity;
      
      for (BusStop stop in firstRouteStops) {
        double walkDistance = _calculateDistance(_fromLocation!, stop.position);
        if (walkDistance <= _maxWalkingDistance && walkDistance < minWalkToFirst) {
          minWalkToFirst = walkDistance;
          firstBoardingStop = stop;
        }
      }
      
      if (firstBoardingStop != null) {
        // Find transfer points (stops with same or similar names on different routes)
        for (BusStop transferCandidate in firstRouteStops) {
          if (transferCandidate.stopOrder >= firstBoardingStop.stopOrder) {
            // Look for stops on destination route that could be transfer points
            List<BusStop> destRouteStops = _busStops
                .where((stop) => stop.routeId == destStop.routeId)
                .toList();
            
            for (BusStop destRouteStop in destRouteStops) {
              double transferDistance = _calculateDistance(
                transferCandidate.position, 
                destRouteStop.position
              );
              
              // If stops are very close (within 300m) or have similar names, consider as transfer
              bool isTransferPoint = transferDistance <= 300 || 
                  _areSimilarStops(transferCandidate.name, destRouteStop.name);
              
              if (isTransferPoint && destRouteStop.stopOrder < destStop.stopOrder) {
                // Create transfer route
                List<BusStop> firstSegmentStops = firstRouteStops
                    .where((stop) => 
                        stop.stopOrder >= firstBoardingStop!.stopOrder && 
                        stop.stopOrder <= transferCandidate.stopOrder)
                    .toList();
                
                List<BusStop> secondSegmentStops = destRouteStops
                    .where((stop) => 
                        stop.stopOrder >= destRouteStop.stopOrder && 
                        stop.stopOrder <= destStop.stopOrder)
                    .toList()
                  ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
                
                if (firstSegmentStops.isNotEmpty && secondSegmentStops.isNotEmpty) {
                  List<RouteSegment> segments = [
                    RouteSegment(
                      startStop: firstBoardingStop,
                      endStop: transferCandidate,
                      routeName: transferCandidate.routeName,
                      routeId: transferCandidate.routeId,
                      pathStops: firstSegmentStops,
                      travelTime: _calculateBusTime(firstBoardingStop, transferCandidate),
                      distance: _calculateRouteDistance(firstSegmentStops),
                    ),
                    RouteSegment(
                      startStop: destRouteStop,
                      endStop: destStop,
                      routeName: destStop.routeName,
                      routeId: destStop.routeId,
                      pathStops: secondSegmentStops,
                      travelTime: _calculateBusTime(destRouteStop, destStop),
                      distance: _calculateRouteDistance(secondSegmentStops),
                    ),
                  ];
                  
                  transferRoutes.add(_createRouteResult(
                    segments: segments,
                    startLocation: _fromLocation!,
                    endLocation: destStop.position,
                    now: now,
                    hasTransfer: true,
                    transferStop: transferCandidate,
                  ));
                }
              }
            }
          }
        }
      }
    }
    
    return transferRoutes;
  }

  bool _areSimilarStops(String name1, String name2) {
    // Simple similarity check - can be enhanced with more sophisticated algorithms
    name1 = name1.toLowerCase().replaceAll(' ', '');
    name2 = name2.toLowerCase().replaceAll(' ', '');
    
    // Check if names are exactly the same
    if (name1 == name2) return true;
    
    // Check if one name contains the other
    if (name1.contains(name2) || name2.contains(name1)) return true;
    
    // Check for common words
    List<String> words1 = name1.split(' ');
    List<String> words2 = name2.split(' ');
    
    for (String word1 in words1) {
      for (String word2 in words2) {
        if (word1.length > 3 && word2.length > 3 && word1 == word2) {
          return true;
        }
      }
    }
    
    return false;
  }

  int _calculateBusTime(BusStop start, BusStop end) {
    int stopDifference = (end.stopOrder - start.stopOrder).abs();
    return math.max(5, stopDifference * 2); // Minimum 5 minutes, 2 minutes per stop
  }

  double _calculateRouteDistance(List<BusStop> stops) {
    if (stops.length < 2) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      totalDistance += _calculateDistance(stops[i].position, stops[i + 1].position);
    }
    return totalDistance;
  }

  RouteResult _createRouteResult({
    required List<RouteSegment> segments,
    required LatLng startLocation,
    required LatLng endLocation,
    required DateTime now,
    required bool hasTransfer,
    BusStop? transferStop,
  }) {
    // Calculate walking distances
    double walkToFirstStop = _calculateDistance(startLocation, segments.first.startStop.position);
    double walkFromLastStop = _calculateDistance(segments.last.endStop.position, endLocation);
    
    // Calculate times
    int walkingTime = ((walkToFirstStop + walkFromLastStop) / _walkingSpeed).round();
    int busTime = segments.fold(0, (sum, segment) => sum + segment.travelTime);
    int waitingTime = _averageWaitTime * segments.length; // Wait time for each bus
    int transferTime = hasTransfer ? _transferPenalty : 0;
    int totalTime = walkingTime + busTime + waitingTime + transferTime;
    
    // Calculate distances
    double totalWalkingDistance = walkToFirstStop + walkFromLastStop;
    double totalBusDistance = segments.fold(0, (sum, segment) => sum + segment.distance);
    
    // Generate description and instructions
    String routeDescription;
    String instructions;
    
    if (hasTransfer) {
      routeDescription = "${segments.first.routeName} → ${segments.last.routeName}";
      instructions = _generateTransferInstructions(segments, walkToFirstStop, walkFromLastStop);
    } else {
      routeDescription = segments.first.routeName;
      instructions = _generateDirectInstructions(segments.first, walkToFirstStop, walkFromLastStop);
    }
    
    // Calculate times
    String startTime = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    DateTime endDateTime = now.add(Duration(minutes: totalTime));
    String endTime = "${endDateTime.hour}:${endDateTime.minute.toString().padLeft(2, '0')}";
    
    // Collect all stops
    List<BusStop> allStops = [];
    for (RouteSegment segment in segments) {
      allStops.addAll(segment.pathStops);
    }
    
    return RouteResult(
      segments: segments,
      allStops: allStops,
      routeDescription: routeDescription,
      totalWalkingTime: walkingTime,
      totalBusTime: busTime,
      totalWaitingTime: waitingTime,
      totalWalkingDistance: totalWalkingDistance,
      totalBusDistance: totalBusDistance,
      instructions: instructions,
      startTime: startTime,
      endTime: endTime,
      totalTime: totalTime,
      transferStop: transferStop,
      hasTransfer: hasTransfer,
      startLocation: startLocation,
      endLocation: endLocation,
    );
  }

  String _generateDirectInstructions(RouteSegment segment, double walkToStop, double walkFromStop) {
    int walkToStopMin = (walkToStop / _walkingSpeed).round();
    int walkFromStopMin = (walkFromStop / _walkingSpeed).round();
    
    return "Walk ${walkToStopMin} min to ${segment.startStop.name} → "
           "Take ${segment.routeName} to ${segment.endStop.name} → "
           "Walk ${walkFromStopMin} min to destination";
  }

  String _generateTransferInstructions(List<RouteSegment> segments, double walkToStop, double walkFromStop) {
    int walkToStopMin = (walkToStop / _walkingSpeed).round();
    int walkFromStopMin = (walkFromStop / _walkingSpeed).round();
    
    return "Walk ${walkToStopMin} min to ${segments.first.startStop.name} → "
           "Take ${segments.first.routeName} to ${segments.first.endStop.name} → "
           "Transfer to ${segments.last.routeName} → "
           "Get off at ${segments.last.endStop.name} → "
           "Walk ${walkFromStopMin} min to destination";
  }

  List<RouteResult> _removeDuplicateRoutes(List<RouteResult> routes) {
    Map<String, RouteResult> uniqueRoutes = {};
    
    for (RouteResult route in routes) {
      String key = route.routeDescription + 
                   route.segments.first.startStop.name + 
                   route.segments.last.endStop.name;
      
      if (!uniqueRoutes.containsKey(key) || 
          uniqueRoutes[key]!.totalTime > route.totalTime) {
        uniqueRoutes[key] = route;
      }
    }
    
    return uniqueRoutes.values.toList();
  }

  double _calculateRouteScore(RouteResult route) {
    // Scoring system: lower is better
    double score = route.totalTime.toDouble();
    
    // Penalties
    if (route.hasTransfer) score += 15; // Transfer penalty
    if (route.totalWalkingDistance > 1000) score += (route.totalWalkingDistance - 1000) / 100; // Long walk penalty
    
    // Bonuses
    if (route.totalWalkingDistance < 500) score -= 5; // Short walk bonus
    if (!route.hasTransfer) score -= 5; // Direct route bonus
    
    return score;
  }

  void _searchRoute() {
    if (_toController.text.isEmpty || _fromLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _showRouteResults = false;
      _showFromSuggestions = false;
      _showToSuggestions = false;
    });
    
    // Find destination
    List<BusStop> matchingStops = _busStops
        .where((stop) => stop.name.toLowerCase().contains(_toController.text.toLowerCase()))
        .toList();
    
    if (matchingStops.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destination not found')),
      );
      return;
    }
    
    // Use the first matching stop for destination marker
    BusStop destStop = matchingStops.first;
    
    setState(() {
      _destination = destStop.position;
      _routeResults = _findAllOptimalRoutes(_toController.text);
      _isLoading = false;
      _showRouteResults = true;
      _selectedRouteIndex = 0;
    });
    
    _animationController.forward();
    
    if (_destination != null && _fromLocation != null) {
      LatLngBounds bounds = LatLngBounds.fromPoints([_fromLocation!, _destination!]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(50)));
    }
  }

  void _swapLocations() {
    setState(() {
      String temp = _fromController.text;
      _fromController.text = _toController.text;
      _toController.text = temp;
      
      LatLng? tempLocation = _fromLocation;
      _fromLocation = _destination;
      _destination = tempLocation;
      
      _useCurrentLocation = false;
    });
  }

  void _selectRoute(int index) {
    setState(() {
      _selectedRouteIndex = index;
    });
    
    if (_routeResults.isNotEmpty) {
      RouteResult route = _routeResults[index];
      List<LatLng> allPoints = [route.startLocation];
      allPoints.addAll(route.allStops.map((stop) => stop.position));
      allPoints.add(route.endLocation);
      
      LatLngBounds bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(50)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with enhanced route visualization
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? LatLng(27.7172, 85.3240),
              initialZoom: 13.0,
              maxZoom: 18.0,
              minZoom: 10.0,
              interactionOptions: InteractionOptions(
                enableMultiFingerGestureRace: true,
                enableScrollWheel: true,
                scrollWheelVelocity: 0.005,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bus_route_finder',
                maxZoom: 18,
                subdomains: const ['a', 'b', 'c'],
              ),
              // Enhanced route visualization
              if (_routeResults.isNotEmpty && _showRouteResults)
                PolylineLayer(
                  polylines: _buildRoutePolylines(),
                ),
              // Bus stops markers with route-specific colors
              MarkerLayer(
                markers: _buildBusStopMarkers(),
              ),
              // Location markers
              MarkerLayer(
                markers: _buildLocationMarkers(),
              ),
            ],
          ),
          
          // Enhanced search interface
          _buildSearchInterface(),
          
          // Transportation mode selector
          if (!_showRouteResults)
            _buildTransportModeSelector(),

          // Enhanced route results bottom sheet
          if (_showRouteResults)
            _buildRouteResultsSheet(),
        ],
      ),
      
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "location",
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
              } else {
                _getCurrentLocation();
              }
            },
            child: Icon(Icons.my_location),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  List<Polyline> _buildRoutePolylines() {
    if (_routeResults.isEmpty || !_showRouteResults) return [];
    
    RouteResult selectedRoute = _routeResults[_selectedRouteIndex];
    List<Polyline> polylines = [];
    
    // Walking path to first stop
    polylines.add(Polyline(
      points: [selectedRoute.startLocation, selectedRoute.segments.first.startStop.position],
      strokeWidth: 4.0,
      color: Colors.green,
    ));
    
    // Bus route segments with different colors
    List<Color> segmentColors = [Colors.blue.shade600, Colors.purple.shade600, Colors.orange.shade600];
    
    for (int i = 0; i < selectedRoute.segments.length; i++) {
      RouteSegment segment = selectedRoute.segments[i];
      polylines.add(Polyline(
        points: segment.pathStops.map((stop) => stop.position).toList(),
        strokeWidth: 6.0,
        color: segmentColors[i % segmentColors.length],
      ));
    }
    
    // Transfer walking path (if applicable)
    if (selectedRoute.hasTransfer && selectedRoute.segments.length > 1) {
      polylines.add(Polyline(
        points: [
          selectedRoute.segments[0].endStop.position,
          selectedRoute.segments[1].startStop.position
        ],
        strokeWidth: 3.0,
        color: Colors.amber,
      ));
    }
    
    // Walking path from last stop to destination
    polylines.add(Polyline(
      points: [selectedRoute.segments.last.endStop.position, selectedRoute.endLocation],
      strokeWidth: 4.0,
      color: Colors.green,
    ));
    
    return polylines;
  }

  List<Marker> _buildBusStopMarkers() {
    if (_showRouteResults && _routeResults.isNotEmpty) {
      // Show only relevant stops for selected route
      RouteResult selectedRoute = _routeResults[_selectedRouteIndex];
      List<Marker> markers = [];
      
      for (int i = 0; i < selectedRoute.segments.length; i++) {
        RouteSegment segment = selectedRoute.segments[i];
        Color segmentColor = i == 0 ? Colors.orange.shade700 : Colors.purple.shade700;
        
        for (BusStop stop in segment.pathStops) {
          markers.add(Marker(
            point: stop.position,
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: segmentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 18,
              ),
            ),
          ));
        }
      }
      
      // Special markers for transfer stops
      if (selectedRoute.hasTransfer && selectedRoute.transferStop != null) {
        markers.add(Marker(
          point: selectedRoute.transferStop!.position,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.transfer_within_a_station,
              color: Colors.white,
              size: 20,
            ),
          ),
        ));
      }
      
      return markers;
    } else {
      // Show sample of all bus stops
      return _busStops.take(30).map((stop) => Marker(
        point: stop.position,
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade600,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_bus,
            color: Colors.white,
            size: 12,
          ),
        ),
      )).toList();
    }
  }

  List<Marker> _buildLocationMarkers() {
    List<Marker> markers = [];
    
    // Current location marker
    if (_currentLocation != null) {
      markers.add(Marker(
        point: _currentLocation!,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location,
            color: Colors.white,
            size: 20,
          ),
        ),
      ));
    }
    
    // From location marker (if different from current)
    if (_fromLocation != null && _fromLocation != _currentLocation) {
      markers.add(Marker(
        point: _fromLocation!,
        width: 35,
        height: 35,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            Icons.place,
            color: Colors.white,
            size: 20,
          ),
        ),
      ));
    }
    
    // Destination marker
    if (_destination != null) {
      markers.add(Marker(
        point: _destination!,
        width: 35,
        height: 35,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            Icons.place,
            color: Colors.white,
            size: 20,
          ),
        ),
      ));
    }
    
    return markers;
  }

  Widget _buildSearchInterface() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // From field
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fromController,
                      decoration: InputDecoration(
                        hintText: 'From (Your Location)',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      readOnly: _useCurrentLocation,
                      onChanged: _useCurrentLocation ? null : _searchFromSuggestions,
                      onTap: () {
                        if (!_useCurrentLocation) {
                          setState(() {
                            _showToSuggestions = false;
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _useCurrentLocation = !_useCurrentLocation;
                        if (_useCurrentLocation) {
                          _fromLocation = _currentLocation;
                          _fromController.text = "Your Location";
                          _showFromSuggestions = false;
                        } else {
                          _fromController.clear();
                        }
                      });
                    },
                    icon: Icon(
                      _useCurrentLocation ? Icons.my_location : Icons.edit_location,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    onPressed: _swapLocations,
                    icon: Icon(
                      Icons.swap_vert,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Container(
              height: 1,
              color: Colors.grey[200],
              margin: EdgeInsets.symmetric(horizontal: 16),
            ),
            
            // To field
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _toController,
                      decoration: InputDecoration(
                        hintText: 'To (Destination)',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      onChanged: _searchToSuggestions,
                      onTap: () {
                        setState(() {
                          _showFromSuggestions = false;
                        });
                      },
                      onSubmitted: (_) => _searchRoute(),
                    ),
                  ),
                  IconButton(
                    onPressed: _searchRoute,
                    icon: Icon(
                      Icons.search,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            // From suggestions
            if (_showFromSuggestions)
              Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _fromSuggestions.length,
                  itemBuilder: (context, index) {
                    BusStop stop = _fromSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.directions_bus, color: Colors.orange),
                      title: Text(stop.name),
                      subtitle: Text(stop.routeName),
                      onTap: () {
                        setState(() {
                          _fromController.text = stop.name;
                          _fromLocation = stop.position;
                          _showFromSuggestions = false;
                          _useCurrentLocation = false;
                        });
                      },
                    );
                  },
                ),
              ),
            
            // To suggestions
            if (_showToSuggestions)
              Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _toSuggestions.length,
                  itemBuilder: (context, index) {
                    BusStop stop = _toSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.directions_bus, color: Colors.orange),
                      title: Text(stop.name),
                      subtitle: Text(stop.routeName),
                      onTap: () {
                        setState(() {
                          _toController.text = stop.name;
                          _destination = stop.position;
                          _showToSuggestions = false;
                        });
                        _searchRoute();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportModeSelector() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTransportIcon(Icons.directions_walk, false),
            _buildTransportIcon(Icons.motorcycle, false),
            _buildTransportIcon(Icons.directions_car, false),
            _buildTransportIcon(Icons.directions_bus, true),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteResultsSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _animation.value) * 400),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header with close button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Route Options',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showRouteResults = false;
                              _animationController.reverse();
                            });
                          },
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  // Route results list
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Finding optimal routes...'),
                                Text('Checking all bus lines...', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : _routeResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 50, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No routes found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Try a different destination or check spelling',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _routeResults.length,
                                itemBuilder: (context, index) {
                                  return _buildEnhancedRouteCard(index);
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedRouteCard(int index) {
    RouteResult route = _routeResults[index];
    bool isSelected = index == _selectedRouteIndex;
    
    return GestureDetector(
      onTap: () => _selectRoute(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route header with transfer indicator
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: route.hasTransfer ? Colors.amber : (isSelected ? Colors.blue : Colors.orange),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      route.hasTransfer ? 'Transfer' : 'Direct',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.routeDescription,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${route.totalTime} min',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (index == 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Time range and route info
              Row(
                children: [
                  Text(
                    '${route.startTime} - ${route.endTime}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  if (route.hasTransfer)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '1 Transfer',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Enhanced journey visualization
              _buildJourneyVisualization(route),
              
              SizedBox(height: 12),
              
              // Detailed breakdown
              Row(
                children: [
                  _buildTimeBreakdown(Icons.directions_walk, route.totalWalkingTime, 'Walk', Colors.green),
                  SizedBox(width: 16),
                  _buildTimeBreakdown(Icons.directions_bus, route.totalBusTime, 'Bus', Colors.blue),
                  SizedBox(width: 16),
                  _buildTimeBreakdown(Icons.access_time, route.totalWaitingTime, 'Wait', Colors.orange),
                  if (route.hasTransfer) ...[
                    SizedBox(width: 16),
                    _buildTimeBreakdown(Icons.transfer_within_a_station, 10, 'Transfer', Colors.amber),
                  ],
                ],
              ),
              
              SizedBox(height: 12),
              
              // Distance info
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      'Walk: ${(route.totalWalkingDistance / 1000).toStringAsFixed(1)} km',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.route, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      'Bus: ${(route.totalBusDistance / 1000).toStringAsFixed(1)} km',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 8),
              
              // Instructions
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  route.instructions,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyVisualization(RouteResult route) {
    return Container(
      height: 60,
      child: Row(
        children: [
          // Walk to first stop
          Expanded(
            flex: 2,
            child: _buildJourneyStep(
              Icons.directions_walk,
              'Walk to\n${route.segments.first.startStop.name}',
              '${route.totalWalkingTime ~/2} min',
              Colors.green,
              isStart: true,
            ),
          ),
          
          // Arrow
          Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
          
          // First bus segment
          Expanded(
            flex: 3,
            child: _buildJourneyStep(
              Icons.directions_bus,
              route.segments.first.routeName,
              '${route.segments.first.travelTime} min',
              Colors.blue,
            ),
          ),
          
          // Transfer section (if applicable)
          if (route.hasTransfer) ...[
            Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
            Expanded(
              flex: 2,
              child: _buildJourneyStep(
                Icons.transfer_within_a_station,
                'Transfer',
                '5 min',
                Colors.amber,
              ),
            ),
            Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
            Expanded(
              flex: 3,
              child: _buildJourneyStep(
                Icons.directions_bus,
                route.segments.last.routeName,
                '${route.segments.last.travelTime} min',
                Colors.purple,
              ),
            ),
          ],
          
          // Arrow
          Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
          
          // Walk to destination
          Expanded(
            flex: 2,
            child: _buildJourneyStep(
              Icons.directions_walk,
              'Walk to\nDestination',
              '${route.totalWalkingTime - (route.totalWalkingTime ~/2)} min',
              Colors.green,
              isEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBreakdown(IconData icon, int time, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(height: 2),
        Text(
          '${time}m',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTransportIcon(IconData icon, bool isSelected) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.grey[600],
        size: 24,
      ),
    );
  }

  Widget _buildJourneyStep(IconData icon, String label, String duration, Color color, {bool isStart = false, bool isEnd = false}) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            duration,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
}