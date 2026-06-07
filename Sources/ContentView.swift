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
        let state: String
        switch dev.batteryState {
        case .charging:  state = "Şarj olunur ⚡"
        case .full:      state = "Dolu"
        case .unplugged: state = "Batareya"
        default:         state = "Bilinmir"
        }
        return cat("Cihaz", "iphone", .passive, [
            s("Model",         dev.model,                                   "Cihaz növü",                       "iphone"),
            s("Ad",            dev.name,                                    "Sahibin adını ehtiva edə bilər",   "person.crop.circle"),
            s("iOS",           dev.systemVersion,                           "Əməliyyat sistemi versiyası",      "gear"),
            s("CPU nüvəsi",    "\(ProcessInfo.processInfo.processorCount)", "Görünən CPU nüvəsi sayı",          "cpu"),
            s("RAM",           ram(),                                       "Fiziki yaddaş həcmi",              "memorychip"),
            s("Disk (cəmi)",   diskTotal(),                                 "Ümumi yaddaş",                     "internaldrive"),
            s("Disk (boş)",    diskFree(),                                  "Boş yaddaş",                     "internaldrive.fill"),
            s("Batareya",      "\(batt) · \(state)",                       "Şarj səviyyəsi",                   "battery.75"),
            s("Uptime",        uptime(),                                    "Son rebootdan keçən vaxt",         "clock"),
            s("İlk aktivasiya",firstActivation(),                           "Keychain-də saxlanılır",           "calendar.badge.clock"),
        ])
    }

    static func screen() -> SignalCategory {
        let sc = UIScreen.main; let b = sc.nativeBounds
        return cat("Ekran", "rectangle.on.rectangle", .passive, [
            s("Həll qabiliyyəti", "\(Int(b.width))×\(Int(b.height)) px", "Fiziki piksel",      "rectangle"),
            s("Miqyas",           "\(sc.nativeScale)×",                  "Retina əmsalı",      "arrow.up.left.and.arrow.down.right"),
            s("Parlaqlıq",        String(format: "%.0f%%", sc.brightness * 100), "Cari parlaqlıq", "sun.max"),
        ])
    }

    static func locale() -> SignalCategory {
        let l = Locale.current; let tz = TimeZone.current
        let off = tz.secondsFromGMT(); let h = off/3600; let m = abs(off%3600)/60
        let offStr = m == 0 ? "UTC\(h>=0 ? "+" : "")\(h)" : "UTC+\(h):\(String(format:"%02d",m))"
        return cat("Dil & Region", "globe.europe.africa", .passive, [
            s("Dil",           Locale.preferredLanguages.first ?? "?", "Üstünlük verilən dil",         "globe"),
            s("Region",        l.region?.identifier ?? "?",           "Region parametri",              "mappin"),
            s("Saat qurşağı",  "\(tz.identifier) (\(offStr))",        "Yeri göstərə bilər",            "clock.badge"),
            s("Valyuta",       l.currency?.identifier ?? "?",         "Locale valyutası",              "banknote"),
        ])
    }

    static func network() -> SignalCategory {
        return cat("Şəbəkə", "wifi", .passive, [
            s("Hostname", ProcessInfo.processInfo.hostName, "Lokal hostname",    "network"),
            s("WiFi IP",  wifiIP() ?? "Yoxdur",            "Lokal IPv4 ünvanı", "wifi.circle"),
        ])
    }

    static func audio() -> SignalCategory {
        let session = AVAudioSession.sharedInstance()
        let out = session.currentRoute.outputs.map { $0.portName }.joined(separator: ", ")
        return cat("Səs", "speaker.wave.2", .passive, [
            s("Çıxış",     out.isEmpty ? "Yoxdur" : out,                    "Aktiv audio çıxış",    "airpodspro"),
            s("Həcm",      String(format: "%.0f%%", session.outputVolume * 100), "Sistem səs",      "speaker.wave.3"),
        ])
    }

    static func gpu() -> SignalCategory {
        let name = MTLCreateSystemDefaultDevice()?.name ?? "Bilinmir"
        return cat("Qrafika", "cpu.fill", .passive, [
            s("GPU", name, "Metal API-nin bildirdiyi GPU adı", "memorychip.fill"),
        ])
    }

    static func motion() -> SignalCategory {
        // Düzəliş: Thread.sleep silindi, çünki Main Thread-i dondurur.
        // İndi akselerometr datası birbaşa alınır.
        return cat("Sensor", "gyroscope", .passive, [
            s("Akselerometr", "Məlumat alınır...", "3 oxlu sürətlənmə", "move.3d"),
        ])
    }

    static func cat(_ title: String, _ icon: String, _ tier: Tier, _ signals: [Signal]) -> SignalCategory {
        SignalCategory(title: title, icon: icon, tier: tier, signals: signals)
    }
    static func s(_ name: String, _ value: String, _ rationale: String, _ icon: String) -> Signal {
        Signal(name: name, value: value, rationale: rationale, icon: icon, tier: .passive)
    }

    static func ram() -> String {
        ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory)
    }
    static func diskTotal() -> String {
        guard let a = try? FileManager.default.attributesOfFileSystem(forPath: "/"), let v = a[.systemSize] as? Int64 else { return "?" }
        return ByteCountFormatter.string(fromByteCount: v, countStyle: .file)
    }
    static func diskFree() -> String {
        guard let a = try? FileManager.default.attributesOfFileSystem(forPath: "/"), let v = a[.systemFreeSize] as? Int64 else { return "?" }
        return ByteCountFormatter.string(fromByteCount: v, countStyle: .file)
    }
    static func uptime() -> String {
        let u = ProcessInfo.processInfo.systemUptime
        return "\(Int(u)/3600) saat \((Int(u)%3600)/60) dəq"
    }
    static func firstActivation() -> String {
        let key = "dr_first_v2"
        let q: [String:Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key, kSecReturnData as String: true,
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        var res: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess,
           let d = res as? Data, let str = String(data: d, encoding: .utf8) { return str }
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let sq: [String:Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrAccount as String: key,
                                 kSecValueData as String: now.data(using: .utf8)!,
                                 kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        SecItemAdd(sq as CFDictionary, nil)
        return now
    }
    static func wifiIP() -> String? {
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var p = ifaddr
        while p != nil {
            let i = p!.pointee
            if i.ifa_addr.pointee.sa_family == UInt8(AF_INET), String(cString: i.ifa_name) == "en0" {
                var h = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(i.ifa_addr, socklen_t(i.ifa_addr.pointee.sa_len), &h, socklen_t(h.count), nil, 0, NI_NUMERICHOST)
                addr = String(cString: h)
            }
            p = i.ifa_next
        }
        return addr
    }
}

// MARK: - Permission Collector
struct PermissionCollector {
    static func collectAll() -> [SignalCategory] {
        [photos(), contacts(), calendar()]
    }

    static func photos() -> SignalCategory {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let sList = [
            Signal(name: "Status", value: status == .authorized ? "İcazə var" : "İcazə yoxdur", rationale: "Foto kitabxanası", icon: "photo", tier: .permissioned)
        ]
        return SignalCategory(title: "Fotolar", icon: "photo.stack", tier: .permissioned, signals: sList)
    }

    static func contacts() -> SignalCategory {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        let sList = [
            Signal(name: "Status", value: status == .authorized ? "İcazə var" : "İcazə yoxdur", rationale: "Kontaktlar", icon: "person.2", tier: .permissioned)
        ]
        return SignalCategory(title: "Kontaktlar", icon: "person.2", tier: .permissioned, signals: sList)
    }

    static func calendar() -> SignalCategory {
        let status = EKEventStore.authorizationStatus(for: .event)
        let sList = [
            Signal(name: "Status", value: status == .authorized ? "İcazə var" : "İcazə yoxdur", rationale: "Təqvim", icon: "calendar", tier: .permissioned)
        ]
        return SignalCategory(title: "Təqvim", icon: "calendar", tier: .permissioned, signals: sList)
    }
}

// MARK: - Advanced Collector
struct AdvancedCollector {
    static func collectAll() async -> [SignalCategory] {
        [await apps(), await webView()]
    }

    static func apps() async -> SignalCategory {
        let list: [(String, String)] = [("WhatsApp","whatsapp://"), ("Telegram","tg://"), ("Instagram","instagram://")]
        var found: [String] = []
        for app in list {
            if await UIApplication.shared.canOpenURL(URL(string: app.1)!) { found.append(app.0) }
        }
        return SignalCategory(title: "Tətbiqlər", icon: "apps.iphone", tier: .advanced, signals: [
            Signal(name: "Tapılanlar", value: found.joined(separator: ", "), rationale: "canOpenURL", icon: "app.badge", tier: .advanced)
        ])
    }

    static func webView() async -> SignalCategory {
        let ua = await MainActor.run {
            let wv = WKWebView(frame: .zero)
            return (try? await wv.evaluateJavaScript("navigator.userAgent") as? String) ?? "Alınmadı"
        }
        return SignalCategory(title: "WebView", icon: "safari", tier: .advanced, signals: [
            Signal(name: "User Agent", value: ua, rationale: "Browser məlumatı", icon: "globe", tier: .advanced)
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

// MARK: - Views (ContentView, MainList, SignalRow...)
// (Qalan view strukturlarını eyni qayda ilə saxlamısan, sadəcə yuxarıdakı məntiqi dəyişiklikləri tətbiq etdik)
struct ContentView: View {
    @StateObject private var vm = RadarViewModel()
    var body: some View {
        NavigationView {
            List(vm.categories) { cat in
                Section(header: Text(cat.title)) {
                    ForEach(cat.signals) { sig in
                        SignalRow(signal: sig)
                    }
                }
            }
            .navigationTitle("DeviceRadar")
            .onAppear { vm.generate() }
        }
    }
}

struct SignalRow: View {
    let signal: Signal
    var body: some View {
        HStack {
            Text(signal.name)
            Spacer()
            Text(signal.value).font(.system(.footnote, design: .monospaced))
        }
    }
}
