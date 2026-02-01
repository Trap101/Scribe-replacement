import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/protocol_model.dart';

class ProtocolService {
  static List<JrcalcProtocol>? _cached;

  Future<List<JrcalcProtocol>> loadProtocols() async {
    if (_cached != null) return _cached!;

    final jsonStr = await rootBundle.loadString('assets/JRCALC_Protocols.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final protocols = (data['protocols'] as List)
        .map((p) => JrcalcProtocol.fromJson(p as Map<String, dynamic>))
        .toList();
    _cached = protocols;
    return protocols;
  }

  Future<List<JrcalcProtocol>> searchProtocols(String query) async {
    final protocols = await loadProtocols();
    if (query.isEmpty) return protocols;
    final lower = query.toLowerCase();
    return protocols
        .where((p) =>
            p.name.toLowerCase().contains(lower) ||
            p.category.toLowerCase().contains(lower) ||
            p.triggers.any((t) => t.toLowerCase().contains(lower)))
        .toList();
  }
}
