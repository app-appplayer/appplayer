/// Shared io device-driver wiring — vendored recipe.
///
/// Implements the io device-driver model:
///   - [IoDriverRegistry] / [IoDeviceConfig] — type-keyed builders with
///     per-driver platform gating (the provisioner).
///   - [registerNetworkDrivers] — builders for the dart:io socket drivers
///     (modbus / mqtt / http / scpi) that run on mobile + desktop.
///   - [ioDeviceTools] — the host-agnostic tool map (`io.*` + connect /
///     disconnect) a host registers into its dispatcher / server registry.
///
/// `mcp_io` core is not modified; FFI/native drivers (serial, can) and the
/// session-based opcua / websocket plug in under the same builder pattern.
library;

export 'src/io_device_provisioner.dart';
export 'src/network_drivers.dart';
export 'src/local_drivers.dart';
export 'src/io_device_tools.dart';
