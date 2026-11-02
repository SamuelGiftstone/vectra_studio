/// Base exception for `.vectra` project storage and export failures.
class ProjectStorageException implements Exception {
  final String message;
  final Object? cause;

  const ProjectStorageException(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Thrown when a `.vectra` file contains malformed or invalid JSON data.
class ProjectFormatException extends ProjectStorageException {
  const ProjectFormatException(super.message, [super.cause]);
}

/// Thrown when a `.vectra` file targets an unsupported schema version.
class UnsupportedDocumentVersionException extends ProjectStorageException {
  final int foundVersion;
  final int maxSupportedVersion;

  UnsupportedDocumentVersionException({
    required this.foundVersion,
    required this.maxSupportedVersion,
  }) : super(
          'Unsupported .vectra project version ($foundVersion). '
          'This build of VECTRA Studio supports up to version $maxSupportedVersion.',
        );
}
