/// Desktop io capability registration — public entry.
///
/// Resolves to the real implementation on platforms with `dart:io`
/// (`io_capability_io.dart`, further gated to desktop at runtime), and to a
/// no-op stub on web (`io_capability_stub.dart`). The `mcp_io` family imports
/// `dart:io`, so it must never reach a web build — the conditional export
/// keeps it out.
library;

export 'io_capability_stub.dart'
    if (dart.library.io) 'io_capability_io.dart';
