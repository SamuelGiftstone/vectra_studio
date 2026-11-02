import '../models/group_object.dart';
import '../models/vector_layer.dart';
import '../models/vector_object.dart';

/// Generates consistent default object names (e.g., `Rectangle 01`, `Text 01`,
/// `Group 01`, `Image 01`) and sanitizes user-entered names across Floating Tags,
/// Layers Panel, and Inspector.
class ObjectNamingService {
  ObjectNamingService._();

  /// Generates the next available sequential name for [type] across all layers
  /// and nested groups (e.g., `Rectangle 01`, `Text 02`, `Group 01`).
  static String nextSequentialName({
    required VectorObjectType type,
    required List<VectorLayer> layers,
    String? customPrefix,
  }) {
    final prefix = (customPrefix != null && customPrefix.trim().isNotEmpty)
        ? customPrefix.trim()
        : type.displayLabel;

    final existingNames = <String>{};
    for (final layer in layers) {
      _collectNames(layer.objects, existingNames);
    }

    var index = 1;
    while (true) {
      final padded = index.toString().padLeft(2, '0');
      final candidate = '$prefix $padded';
      final unpadded = '$prefix $index';
      if (!existingNames.contains(candidate) &&
          !existingNames.contains(unpadded)) {
        return candidate;
      }
      index++;
    }
  }

  /// Sanitizes user-edited object names, falling back cleanly to [fallbackName]
  /// when empty or whitespace-only.
  static String sanitizeName(String rawInput, {required String fallbackName}) {
    final cleaned = rawInput.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (cleaned.isEmpty) {
      return fallbackName;
    }
    if (cleaned.length > 120) {
      return cleaned.substring(0, 120).trim();
    }
    return cleaned;
  }

  static void _collectNames(List<VectorObject> objects, Set<String> sink) {
    for (final obj in objects) {
      sink.add(obj.name);
      if (obj is GroupObject) {
        _collectNames(obj.children, sink);
      }
    }
  }
}
