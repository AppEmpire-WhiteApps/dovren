import Foundation

/// Ordered HTTPS origins. A blocked CDN or network-specific port 80 must not
/// be the sole readiness gate. Both probes use authenticated SOCKS and 443.
struct TunnelProbeTarget: Equatable {
  let host: String
  let path: String
  let port: Int

  var url: URL {
    URL(string: "https://\(host)\(path)")!
  }
}

enum TunnelProbeOutcome: Equatable {
  case ready
  case degraded
  case failed
}

enum TunnelProbePolicy {
  static let targets: [TunnelProbeTarget] = [
    TunnelProbeTarget(host: "www.gstatic.com", path: "/generate_204", port: 443),
    TunnelProbeTarget(host: "www.apple.com", path: "/library/test/success.html", port: 443),
  ]

  /// An authenticated SOCKS connection alone is not proof of remote data.
  /// Degraded remains protected but is NOT advertised as CONNECTED.
  static func classify(
    hevRunning: Bool, authenticatedInbound: Bool,
    remoteConnect: Bool, verifiedHTTPS: Bool
  ) -> TunnelProbeOutcome {
    guard hevRunning, authenticatedInbound, remoteConnect else { return .failed }
    return verifiedHTTPS ? .ready : .degraded
  }
}
