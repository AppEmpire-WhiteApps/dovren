require 'fileutils'
require 'pathname'

# Keep the hosted plugin untouched; compile an app-local copy with its Network ID.
def configure_vpn_provider_bundle_id(installer)
  target = installer.pods_project.targets.find { |entry| entry.name == 'flutter_vless' }
  raise 'flutter_vless target is missing from the Pods project' unless target

  references = target.source_build_phase.files.map(&:file_ref).compact.select do |reference|
    File.basename(reference.path.to_s) == 'FlutterVlessPlugin.swift'
  end
  raise 'Expected one compiled FlutterVlessPlugin.swift source' unless references.length == 1

  ios_root = Pathname.new(__dir__).parent
  plugin_root = ios_root.join('.symlinks/plugins/flutter_vless/ios')
  podspec = plugin_root.join('flutter_vless.podspec').read
  unless podspec.match?(/s\.version\s*=\s*['"]1\.1\.6['"]/)
    raise 'Review the Network ID adapter before changing flutter_vless 1.1.6'
  end

  source_path = plugin_root.join('flutter_vless/Sources/flutter_vless/FlutterVlessPlugin.swift')
  source = source_path.read
  signature = '        self.packetTunnelManager = PacketTunnelManager(providerBundleIdentifier: "\(providerBundleIdentifier).XrayTunnel",'
  unless source.scan(Regexp.new(Regexp.escape(signature))).length == 1
    raise 'flutter_vless initialization changed; review the Network ID adapter'
  end

  replacement = <<~'SWIFT'
    guard let packetTunnelBundleIdentifier = Bundle.main.object(
        forInfoDictionaryKey: "FlutterVlessPacketTunnelBundleIdentifier"
    ) as? String,
        !packetTunnelBundleIdentifier.isEmpty,
        !packetTunnelBundleIdentifier.contains("$(") else {
        result(FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "Packet tunnel bundle identifier is missing or unresolved.",
            details: nil
        ))
        return
    }
    self.packetTunnelManager = PacketTunnelManager(providerBundleIdentifier: packetTunnelBundleIdentifier,
  SWIFT
  replacement = replacement.lines.map { |line| "        #{line}" }.join.rstrip
  patched_source = source.sub(signature, replacement)

  pods_root = Pathname.new(installer.sandbox.root)
  overlay_directory = pods_root.join('FlutterVlessOverlay')
  destination = overlay_directory.join('FlutterVlessPlugin.swift')
  if overlay_directory.symlink? || destination.symlink?
    raise 'Refusing to write the Network ID adapter through a symlink'
  end

  FileUtils.mkdir_p(overlay_directory)
  unless destination.file? && destination.read == patched_source
    destination.write(patched_source)
  end

  reference = references.first
  reference.source_tree = 'SOURCE_ROOT'
  reference.path = destination.relative_path_from(pods_root).to_s
end
