/// No raw message bodies, arbitrary routes, strategy metadata or credentials.
class PhoneAlert {
  const PhoneAlert({
    required this.eventId,
    required this.signalId,
    required this.type,
  });
  final String eventId;
  final String signalId;
  final String type;
  String get signalPath => '/signals/$signalId';

  String get title => switch (type) {
        'TP' => 'CPT Market Update · TP reached',
        'CANCELLED' => 'CPT Market Update · Cancelled',
        'SL' => 'CPT Market Update · SL reached',
        _ => 'CPT Market Direction',
      };

  static PhoneAlert? parse(Map<String, dynamic> data) {
    final event = data['event_id'];
    final signal = data['signal_id'];
    final type = data['type'];
    final uuid =
        RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');
    if (event is! String ||
        signal is! String ||
        !uuid.hasMatch(event) ||
        !uuid.hasMatch(signal)) {
      return null;
    }
    if (!['SIGNAL_PUBLISHED', 'TP', 'SL', 'CANCELLED'].contains(type)) {
      return null;
    }
    return PhoneAlert(eventId: event, signalId: signal, type: type as String);
  }
}
