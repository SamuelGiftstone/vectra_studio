import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vector_layer.dart';
import 'document_provider.dart';

/// Ordered layers from [currentDocumentProvider] (bottom-to-top painting order).
final layersListProvider = Provider<List<VectorLayer>>((ref) {
  return ref.watch(currentDocumentProvider.select((doc) => doc.layers));
});

/// Currently active layer ID in the document.
final activeLayerIdProvider = Provider<String>((ref) {
  return ref.watch(currentDocumentProvider.select((doc) => doc.activeLayerId));
});
