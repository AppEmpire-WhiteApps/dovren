// Packet tunnel driven by SwiftyXrayKit (dima-u/SwiftyXrayKit 2.x),
// the same Xray package EndpointLab uses. Packets go straight from
// NEPacketTunnelFlow into Xray's TUN inbound. There is no SOCKS listener
// and no tun2socks process.
//
// The saved profile, on-demand policy and provider messages stay on the
// flutter_vless contract the app already speaks.

import Foundation
import NetworkExtension
import SwiftyXrayKit
import os

private let tunnelLog = NativePrivacyLogger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.DovrenAdBlockwa1645.app.netextension",
  category: "PacketTunnel"
)
private let tunnelMTU: NSNumber = 1360

/// iOS runs this extension in a separate process from the Flutter app, and the
/// Runner console does not reliably show extension stdout. A small in-memory
/// ring buffer lets the app ask the provider for the exact startup evidence.
private final class TunnelDebugStore {
  static let shared = TunnelDebugStore()
  private let lock = NSLock()
  private var lines: [String] = []
  private let maxLines = 120
  private var fileURL: URL?

  func configure(groupIdentifier: String?) {
    lock.lock()
    defer { lock.unlock() }
    guard let groupIdentifier,
      !groupIdentifier.isEmpty,
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: groupIdentifier
      )
    else {
      fileURL = nil
      return
    }
    NativeLogPrivacy.removeLegacyProviderLog(in: containerURL)
    fileURL = containerURL.appendingPathComponent(NativeLogPrivacy.providerLogFilename)
  }

  func append(_ message: NativeDiagnosticMessage) {
    lock.lock()
    defer { lock.unlock() }
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message.text)"
    lines.append(line)
    if lines.count > maxLines {
      lines.removeFirst(lines.count - maxLines)
    }
    if let fileURL {
      try? TunnelFileLog.append(line, to: fileURL)
    }
  }

  func snapshot() -> String {
    lock.lock()
    defer { lock.unlock() }
    if let fileURL,
      let persisted = try? TunnelFileLog.tail(of: fileURL),
      !persisted.isEmpty
    {
      return persisted
    }
    return lines.joined(separator: "\n")
  }

  /// Working directory for Xray geo data and the rewritten config. Lives in
  /// the app-group cache so a restarted extension can find it again.
  func cacheDirectory() -> URL? {
    lock.lock()
    defer { lock.unlock() }
    return fileURL?.deletingLastPathComponent()
  }
}

private func rememberTunnelLog(_ message: NativeDiagnosticMessage) {
  TunnelDebugStore.shared.append(message)
}

class NboPacketTunnelProvider: NEPacketTunnelProvider {

  private var bridge: XrayBridge?
  private let forwardingLock = NSLock()
  private var forwardingReady = false
  private var startupStopped = false

  private func setForwardingReady(_ ready: Bool) {
    forwardingLock.lock()
    forwardingReady = ready && !startupStopped
    // A late callback must not reassert a tunnel that is stopping.
    reasserting = !ready && !startupStopped
    forwardingLock.unlock()
  }

  private func isForwardingReady() -> Bool {
    forwardingLock.lock()
    defer { forwardingLock.unlock() }
    return forwardingReady && bridge != nil
  }

  private func isStartupStopped() -> Bool {
    forwardingLock.lock()
    defer { forwardingLock.unlock() }
    return startupStopped
  }

  /// Runs before the first await, so the lock stays out of the async context.
  private func beginStartup() {
    forwardingLock.lock()
    startupStopped = false
    forwardingLock.unlock()
  }

  override func startTunnel(options: [String: NSObject]? = nil) async throws {
    guard let configuration = protocolConfiguration as? NETunnelProviderProtocol else {
      throw tunnelError("Missing tunnel provider configuration")
    }
    let providerConfiguration = configuration.providerConfiguration ?? [:]
    let bypassArgument = providerConfiguration["bypassSubnets"]
    guard
      bypassArgument == nil || bypassArgument is NSNull
        || (bypassArgument as? [String])?.isEmpty == true
    else {
      throw tunnelError("System route exclusions are unsupported; use Xray direct rules")
    }

    let config = try TunnelSecretProfile.load(
      providerConfiguration,
      providerBundleIdentifier: configuration.providerBundleIdentifier ?? ""
    )
    guard let configText = String(data: config, encoding: .utf8), !configText.isEmpty else {
      throw tunnelError("Saved Xray configuration is not UTF-8 text")
    }
    TunnelDebugStore.shared.configure(
      groupIdentifier: providerConfiguration["groupIdentifier"] as? String)
    beginStartup()
    setForwardingReady(false)
    rememberTunnelLog("Starting Xray packet tunnel")

    TunnelOnDemandPolicy.enableForStart(
      configuration: configuration,
      isCancelled: { self.isStartupStopped() }
    ) { result in
      switch result {
      case .success:
        rememberTunnelLog("On-demand recovery armed for tunnel session")
      case .failure:
        rememberTunnelLog("Unable to arm on-demand recovery for tunnel session")
      }
    }
    guard !isStartupStopped() else { throw CancellationError() }

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
    settings.mtu = tunnelMTU
    let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
    ipv4.includedRoutes = [NEIPv4Route.default()]
    settings.ipv4Settings = ipv4
    // A default IPv6 route can keep setTunnelNetworkSettings unfinished.
    settings.ipv6Settings = nil
    let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
    dns.matchDomains = [""]
    settings.dnsSettings = dns
    try await setTunnelNetworkSettings(settings)
    guard !isStartupStopped() else { throw CancellationError() }
    rememberTunnelLog("Protected tunnel routes installed")

    let cache =
      TunnelDebugStore.shared.cacheDirectory()
      ?? FileManager.default.temporaryDirectory
    let dataDir = cache.appendingPathComponent("xray-data", isDirectory: true)
    let finalConfig = cache.appendingPathComponent("xray-config.json")
    try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

    let xrayBridge = XrayBridge(packetFlow: packetFlow)
    try xrayBridge.start(
      config: .json(configText),
      dataDir: dataDir,
      finalConfigPath: finalConfig,
      preset: .mobile,
      traceHandle: { message in
        rememberTunnelLog(NativeDiagnosticMessage(stringLiteral: message))
      }
    )
    guard !isStartupStopped() else {
      xrayBridge.stop()
      throw CancellationError()
    }
    bridge = xrayBridge
    setForwardingReady(true)
    rememberTunnelLog("Xray bridge started")
  }

  override func stopTunnel(
    with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
  ) {
    forwardingLock.lock()
    startupStopped = true
    forwardingLock.unlock()
    rememberTunnelLog("Stopping Xray packet tunnel, reason=\(reason.rawValue)")
    setForwardingReady(false)
    let teardown = DispatchGroup()
    teardown.enter()
    if let configuration = protocolConfiguration as? NETunnelProviderProtocol {
      TunnelOnDemandPolicy.disableForUserStop(reason: reason, configuration: configuration) {
        result in
        switch result {
        case .success(.preservedForRecovery):
          rememberTunnelLog("System stop preserves on-demand recovery")
        case .success:
          rememberTunnelLog("User stop: on-demand recovery disabled")
        case .failure:
          rememberTunnelLog(
            "User stop: unable to disable on-demand recovery; use Disconnect in the app")
        }
        teardown.leave()
      }
    } else {
      teardown.leave()
    }
    bridge?.stop()
    bridge = nil
    teardown.notify(queue: .main, execute: completionHandler)
  }

  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    guard let message = String(data: messageData, encoding: .utf8) else {
      completionHandler?(nil)
      return
    }
    if message == "xray_runtime_state" {
      completionHandler?(Data((isForwardingReady() ? "ready" : "recovering").utf8))
    } else if message == "xray_traffic" {
      let stats = bridge?.getAndClearStats()
      let sent = stats?.sent ?? 0
      let received = stats?.received ?? 0
      rememberTunnelLog("Traffic: upBytes=\(sent) downBytes=\(received)")
      completionHandler?("\(sent),\(received)".data(using: .utf8))
    } else if message == "xray_debug" || message == NativeLogPrivacy.snapshotCommand {
      completionHandler?(TunnelDebugStore.shared.snapshot().data(using: .utf8))
    } else if message.hasPrefix("xray_delay") {
      // Delay probes went through the local SOCKS listener. The direct
      // TUN bridge has no such listener, so there is nothing to time.
      completionHandler?(Data("-1".utf8))
    } else {
      completionHandler?(nil)
    }
  }

  private func tunnelError(_ message: NativeDiagnosticMessage) -> NSError {
    tunnelLog.error(message)
    rememberTunnelLog(message)
    return NSError(
      domain: "com.DovrenAdBlockwa1645.app.packet_tunnel", code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: message.text
      ])
  }
}
