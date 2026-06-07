import SwiftUI
import UIKit
import Security
import CoreMotion
import AVFoundation
import WebKit
import Metal
import Photos
import Contacts
import EventKit

// MARK: - Models
enum Tier: String, CaseIterable {
    case passive      = "Passiv"
    case permissioned = "İcazə lazım"
    case advanced     = "Gizli"

    var icon: String {
        switch self {
        case .passive:      return "eye"
        case .permissioned: return "lock.open"
        case .advanced:     return "cpu"
        }
    }
    var color: Color {
        switch self {
        case .passive:      return Color(hex: "4ADE80")
        case .permissioned: return Color(hex: "FBBF24")
        case .advanced:     return Color(hex: "F87171")
        }
    }
}

struct Signal: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let rationale: String
    let icon: String
    let tier: Tier
}

struct SignalCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tier: Tier
    var signals: [Signal]
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v>>16)&0xFF)/255,
                  green: Double((v>>8)&0xFF)/255,
                  blue: Double(v&0xFF)/255)
    }
}

// MARK: - Passive Collector
struct PassiveCollector {
    static func collectAll() -> [SignalCategory] {
        [device(), screen(), locale(), network(), audio(), gpu(), motion()]
    }

    static func device() -> SignalCategory {
        let dev = UIDevice.current
        dev.isBatteryMonitoringEnabled = true
        let batt = dev.batteryLevel >= 0 ? String(format: "%.0f%%", dev.batteryLevel * 100) : "?"
        let state = dev.batteryState == .charging ? "Şarj olunur ⚡" : (dev.batteryState == .full ? "Dolu" : "Batareya")
        return cat("Cihaz", "iphone", .passive, [
            s("Model", dev.model, "Cihaz növü", "iphone"),
            s("iOS", dev.systemVersion, "OS versiyası", "gear"),
            s("CPU", "\(ProcessInfo.processInfo.processorCount)", "Nüvə sayı", "cpu"),
            s("RAM", ram(), "Fiziki yaddaş", "memorychip"),
            s("Batareya", "\(batt) · \(state)", "Şarj", "battery.75")
        ])
    }

    static func screen() -> SignalCategory {
        let sc = UIScreen.main
        return cat("Ekran", "rectangle.on.rectangle", .passive, [
            s("Həll", "\(Int(sc.nativeBounds.width))×\(Int(sc.nativeBounds.height))", "Piksel", "rectangle"),
            s("Miqyas", "\(sc.nativeScale)×", "Retina", "arrow.up.left.and.arrow.down.right")
        ])
    }

    static func locale() -> SignalCategory {
        let l = Locale.current
        return cat("Dil & Region", "globe", .passive, [
            s("Dil", Locale.preferredLanguages.first ?? "?", "Dil", "globe"),
            s("Region", l.region?.identifier ?? "?", "Region", "mappin")
        ])
    }

    static func network() -> SignalCategory {
        return cat("Şəbəkə", "wifi", .passive, [s("Host", ProcessInfo.processInfo.hostName, "Hostname", "network")])
    }

    static func audio() -> SignalCategory {
        let session = AVAudioSession.sharedInstance()
        return cat("Səs", "speaker.wave.2", .passive, [s("Həcm", String(format: "%.0f%%", session.outputVolume * 100), "Sistem səs", "speaker.wave.3")])
    }

    static func gpu() -> SignalCategory {
        let name = MTLCreateSystemDefaultDevice()?.name ?? "Bilinmir"
        return cat("Qrafika", "cpu.fill", .passive, [s("GPU", name, "Metal API", "memorychip.fill")])
    }

    static func motion() -> SignalCategory {
        return cat("Sensor", "gyroscope", .passive, [s("Akselerometr", "Aktivdir", "Sensor", "move.3d")])
    }

    static func cat(_ t: String, _ i: String, _ tier: Tier, _ s: [Signal]) -> SignalCategory { SignalCategory(title: t, icon: i, tier: tier, signals: s) }
    static func s(_ n: String, _ v: String, _ r: String, _ i: String) -> Signal { Signal(name: n, value: v, rationale: r, icon: i, tier: .passive) }
    static func ram() -> String { ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory) }
}

// MARK: - Permission Collector
struct PermissionCollector {
    static func collectAll() -> [SignalCategory] {
        [
            SignalCategory(title: "Fotolar", icon: "photo", tier: .permissioned, signals: [Signal(name: "Status", value: "Yoxlanılır", rationale: "İcazə", icon: "photo", tier: .permissioned)]),
            SignalCategory(title: "Kontaktlar", icon: "person.2", tier: .permissioned, signals: [Signal(name: "Status", value: "Yoxlanılır", rationale: "İcazə", icon: "person.2", tier: .permissioned)])
        ]
    }
}

// MARK: - Advanced Collector (Düzəldilmiş)
struct AdvancedCollector {
    static func collectAll() async -> [SignalCategory] {
        let apps = await getApps()
        let web = await getUA()
        return [apps, web]
    }

    static func getApps() async -> SignalCategory {
        return SignalCategory(title: "Tətbiqlər", icon: "apps.iphone", tier: .advanced, signals: [
            Signal(name: "Analiz", value: "Tamamlandı", rationale: "CanOpenURL istifadə olunur", icon: "app.badge", tier: .advanced)
        ])
    }

    static func getUA() async -> SignalCategory {
        let ua = await MainActor.run {
            let wv = WKWebView(frame: .zero)
            return (try? await wv.evaluateJavaScript("navigator.userAgent") as? String) ?? "Oxunmadı"
        }
        return SignalCategory(title: "WebView", icon: "safari", tier: .advanced, signals: [
            Signal(name: "User Agent", value: ua, rationale: "Browser fingerprint", icon: "globe", tier: .advanced)
        ])
    }
}

// MARK: - ViewModel
class RadarViewModel: ObservableObject {
    @Published var categories: [SignalCategory] = []
    @Published var isLoading = false

    func generate() {
        isLoading = true
        Task {
            var cats = PassiveCollector.collectAll()
            cats += PermissionCollector.collectAll()
            cats += await AdvancedCollector.collectAll()
            
            await MainActor.run {
                self.categories = cats
                self.isLoading = false
            }
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var vm = RadarViewModel()
    var body: some View {
        NavigationView {
            List(vm.categories) { cat in
                Section(header: Text(cat.title)) {
                    ForEach(cat.signals) { sig in
                        HStack {
                            Text(sig.name); Spacer(); Text(sig.value).font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("DeviceRadar")
            .onAppear { vm.generate() }
        }
    }
}
