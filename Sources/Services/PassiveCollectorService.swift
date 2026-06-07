//
//  PassiveCollectorService.swift
//  DeviceRadar
//
//  Created by DeviceRadar Team.
//  Copyright © 2026 LethalLethes. All rights reserved.
//

import Foundation
import UIKit
import Metal
import AVFoundation
import CoreMotion

/// Collects device signals that don't require user permissions.
/// 
/// These signals are accessible to any app without prompts.
/// Collection is fast (~50ms) and lightweight.
class PassiveCollectorService: DataCollectorService {
    private let logger = Logger.shared
    
    func collectSignals() -> [SignalCategory] {
        logger.debug("Starting passive signal collection")
        return [
            collectDevice(),
            collectScreen(),
            collectLocale(),
            collectNetwork(),
            collectAudio(),
            collectGPU(),
            collectMotion()
        ]
    }
    
    // MARK: - Device Signals
    
    private func collectDevice() -> SignalCategory {
        let dev = UIDevice.current
        dev.isBatteryMonitoringEnabled = true
        
        let batteryLevel = dev.batteryLevel >= 0
            ? String(format: "%.0f%%", dev.batteryLevel * 100)
            : "?"
        
        let batteryState: String
        switch dev.batteryState {
        case .charging:
            batteryState = "Şarj olunur ⚡"
        case .full:
            batteryState = "Dolu"
        case .unplugged:
            batteryState = "Batareya"
        default:
            batteryState = "Bilinmir"
        }
        
        return SignalCategory(
            title: "Cihaz",
            icon: "iphone",
            tier: .passive,
            signals: [
                Signal(
                    name: "Model",
                    value: dev.model,
                    rationale: "Cihaz növü",
                    icon: "iphone",
                    tier: .passive
                ),
                Signal(
                    name: "Ad",
                    value: dev.name,
                    rationale: "Sahibin adını ehtiva edə bilər",
                    icon: "person.crop.circle",
                    tier: .passive
                ),
                Signal(
                    name: "iOS",
                    value: dev.systemVersion,
                    rationale: "Əməliyyat sistemi versiyası",
                    icon: "gear",
                    tier: .passive
                ),
                Signal(
                    name: "CPU nüvəsi",
                    value: "\(ProcessInfo.processInfo.processorCount)",
                    rationale: "Görünən CPU nüvəsi sayı",
                    icon: "cpu",
                    tier: .passive
                ),
                Signal(
                    name: "RAM",
                    value: formatBytes(ProcessInfo.processInfo.physicalMemory),
                    rationale: "Fiziki yaddaş həcmi",
                    icon: "memorychip",
                    tier: .passive
                ),
                Signal(
                    name: "Disk (cəmi)",
                    value: diskTotal(),
                    rationale: "Ümumi yaddaş",
                    icon: "internaldrive",
                    tier: .passive
                ),
                Signal(
                    name: "Disk (boş)",
                    value: diskFree(),
                    rationale: "Boş yaddaş",
                    icon: "internaldrive.fill",
                    tier: .passive
                ),
                Signal(
                    name: "Batareya",
                    value: "\(batteryLevel) · \(batteryState)",
                    rationale: "Şarj səviyyəsi",
                    icon: "battery.75",
                    tier: .passive
                ),
                Signal(
                    name: "Uptime",
                    value: formatUptime(),
                    rationale: "Son rebootdan keçən vaxt",
                    icon: "clock",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - Screen Signals
    
    private func collectScreen() -> SignalCategory {
        let screen = UIScreen.main
        let bounds = screen.nativeBounds
        
        return SignalCategory(
            title: "Ekran",
            icon: "rectangle.on.rectangle",
            tier: .passive,
            signals: [
                Signal(
                    name: "Həll qabiliyyəti",
                    value: "\(Int(bounds.width))×\(Int(bounds.height)) px",
                    rationale: "Fiziki piksel",
                    icon: "rectangle",
                    tier: .passive
                ),
                Signal(
                    name: "Miqyas",
                    value: "\(screen.nativeScale)×",
                    rationale: "Retina əmsalı",
                    icon: "arrow.up.left.and.arrow.down.right",
                    tier: .passive
                ),
                Signal(
                    name: "Parlaqlıq",
                    value: String(format: "%.0f%%", screen.brightness * 100),
                    rationale: "Cari parlaqlıq səviyyəsi",
                    icon: "sun.max",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - Locale Signals
    
    private func collectLocale() -> SignalCategory {
        let locale = Locale.current
        let tz = TimeZone.current
        let offset = tz.secondsFromGMT()
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        let offsetStr = minutes == 0 ? "UTC\(hours>=0 ? "+" : "")\(hours)" : "UTC+\(hours):\(String(format:"%02d",minutes))"
        
        return SignalCategory(
            title: "Dil & Region",
            icon: "globe.europe.africa",
            tier: .passive,
            signals: [
                Signal(
                    name: "Dil",
                    value: Locale.preferredLanguages.first ?? "?",
                    rationale: "Üstünlük verilən dil",
                    icon: "globe",
                    tier: .passive
                ),
                Signal(
                    name: "Region",
                    value: locale.region?.identifier ?? "?",
                    rationale: "Region parametri",
                    icon: "mappin",
                    tier: .passive
                ),
                Signal(
                    name: "Saat qurşağı",
                    value: "\(tz.identifier) (\(offsetStr))",
                    rationale: "Yeri göstərə bilər",
                    icon: "clock.badge",
                    tier: .passive
                ),
                Signal(
                    name: "Valyuta",
                    value: locale.currency?.identifier ?? "?",
                    rationale: "Locale valyutası",
                    icon: "banknote",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - Network Signals
    
    private func collectNetwork() -> SignalCategory {
        return SignalCategory(
            title: "Şəbəkə",
            icon: "wifi",
            tier: .passive,
            signals: [
                Signal(
                    name: "Hostname",
                    value: ProcessInfo.processInfo.hostName,
                    rationale: "Lokal hostname",
                    icon: "network",
                    tier: .passive
                ),
                Signal(
                    name: "WiFi IP",
                    value: getWiFiIP() ?? "Yoxdur",
                    rationale: "Lokal IPv4 ünvanı",
                    icon: "wifi.circle",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - Audio Signals
    
    private func collectAudio() -> SignalCategory {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map { $0.portName }.joined(separator: ", ")
        
        return SignalCategory(
            title: "Səs",
            icon: "speaker.wave.2",
            tier: .passive,
            signals: [
                Signal(
                    name: "Çıxış",
                    value: outputs.isEmpty ? "Yoxdur" : outputs,
                    rationale: "Aktiv audio çıxış",
                    icon: "airpodspro",
                    tier: .passive
                ),
                Signal(
                    name: "Həcm",
                    value: String(format: "%.0f%%", session.outputVolume * 100),
                    rationale: "Sistem səs həcmi",
                    icon: "speaker.wave.3",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - GPU Signals
    
    private func collectGPU() -> SignalCategory {
        let gpuName = MTLCreateSystemDefaultDevice()?.name ?? "Bilinmir"
        
        return SignalCategory(
            title: "Qrafika",
            icon: "cpu.fill",
            tier: .passive,
            signals: [
                Signal(
                    name: "GPU",
                    value: gpuName,
                    rationale: "Metal API-nin bildirdiyi GPU adı",
                    icon: "memorychip.fill",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - Motion Signals
    
    private func collectMotion() -> SignalCategory {
        let manager = CMMotionManager()
        var accelValue = "Mövcud deyil"
        
        if manager.isAccelerometerAvailable {
            manager.startAccelerometerUpdates()
            Thread.sleep(forTimeInterval: 0.15)
            if let data = manager.accelerometerData {
                accelValue = String(format: "x=%.3f  y=%.3f  z=%.3f",
                    data.acceleration.x,
                    data.acceleration.y,
                    data.acceleration.z
                )
            }
            manager.stopAccelerometerUpdates()
        }
        
        return SignalCategory(
            title: "Sensor",
            icon: "gyroscope",
            tier: .passive,
            signals: [
                Signal(
                    name: "Akselerometr",
                    value: accelValue,
                    rationale: "3 oxlu sürətlənmə — icazəsiz",
                    icon: "move.3d",
                    tier: .passive
                )
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func diskTotal() -> String {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let size = attributes[.systemSize] as? Int64 else {
            return "?"
        }
        return formatBytes(UInt64(size))
    }
    
    private func diskFree() -> String {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let free = attributes[.systemFreeSize] as? Int64 else {
            return "?"
        }
        return formatBytes(UInt64(free))
    }
    
    private func formatUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours) saat \(minutes) dəq"
    }
    
    private func getWiFiIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: interface.ifa_name) == "en0" {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil, 0,
                    NI_NUMERICHOST
                )
                address = String(cString: hostname)
            }
            ptr = interface.ifa_next
        }
        return address
    }
}
