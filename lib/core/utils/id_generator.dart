import 'dart:math' as math;

/// Generates collision-resistant unique identifiers for documents, layers,
/// vector objects, and path anchors without external dependencies.
class IdGenerator {
  IdGenerator._();

  static final math.Random _random = math.Random();
  static int _sequence = 0;

  static String generate([String prefix = 'id']) {
    _sequence = (_sequence + 1) & 0xFFFFFF;
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final randPart = _random.nextInt(0x7FFFFFFF).toRadixString(36).padLeft(6, '0');
    final seqPart = _sequence.toRadixString(36);
    return '${prefix}_${timestamp}_${seqPart}_$randPart';
  }

  static String documentId() => generate('doc');
  static String layerId() => generate('lyr');
  static String objectId() => generate('obj');
  static String anchorId() => generate('anc');
  static String groupId() => generate('grp');
  static String assetId() => generate('ast');
}

