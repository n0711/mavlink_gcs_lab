enum LinkType { udp, serialRf, replay, unknown }

enum LinkStatus { disconnected, connecting, connected, stale, error }

class LinkEndpoint {
  const LinkEndpoint({
    required this.type,
    required this.label,
    this.host,
    this.port,
    this.serialDevice,
    this.baudRate,
  });

  final LinkType type;
  final String label;
  final String? host;
  final int? port;
  final String? serialDevice;
  final int? baudRate;
}

class LinkHealth {
  const LinkHealth({
    required this.status,
    this.lastMessageAt,
    this.messageRateHz,
    this.packetLossEstimate,
    this.errorMessage,
    this.staleAfter = const Duration(seconds: 5),
  });

  final LinkStatus status;
  final DateTime? lastMessageAt;
  final double? messageRateHz;
  final double? packetLossEstimate;
  final String? errorMessage;
  final Duration staleAfter;

  bool get isStale {
    if (status == LinkStatus.stale) return true;
    if (status != LinkStatus.connected || lastMessageAt == null) return false;
    return DateTime.now().difference(lastMessageAt!) > staleAfter;
  }
}
