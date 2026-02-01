import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(
        (results) => !results.contains(ConnectivityResult.none),
      );
}
