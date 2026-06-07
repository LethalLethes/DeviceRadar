import SwiftUI
import UIKit
import Security
import CoreMotion
import AVFoundation
import WebKit
import Metal
import Darwin

// MARK: - Models

enum Tier: String, CaseIterable {
    case passive     = "Passiv"
    case permissioned = "İcazə lazım"
    case advanced    = "Gizli"

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

    var description: String {
        switch self {
        case .passive:      return "Heç bir icazə olmadan oxunur"
        case .permissioned: return "İOS icazəsi tələb edir"
        case .advanced:     return "Gizli yan kanal metodları"
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

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Signal Collectors

struct PassiveCollector {
    static func collectDevice() -> SignalCategory {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let batteryState: String
        switch device.batteryState {
        case .charging:  batteryState = "Şarj olunur ⚡"
        case .full:      batteryState = "Dolu 🔋"
        case .unplugged: batteryState = "Batareya"
        default:         batteryState = "Bilinmir"
        }

        let batteryLevel = device.batteryLevel >= 0
            ? String(format: "%.0f%%", device.batteryLevel * 100)
            : "?"

        return SignalCategory(title: "Cihaz", icon: "iphone", tier: .passive, signals: [
            Signal(name: "Model", value: device.model,
                   rationale: "Cihaz növü (iPhone, iPad)", icon: "iphone", tier: .passive),
            Signal(name: "Ad", value: device.name,
                   rationale: "Cihazın adı — çox vaxt sahibinin adını ehtiva edir", icon: "person.crop.circle", tier: .passive),
            Signal(name: "iOS", value: device.systemVersion,
                   rationale: "Əməliyyat sistemi versiyası", icon: "gear", tier: .passive),
            Signal(name: "CPU nüvəsi", value: "\(ProcessInfo.processInfo.processorCount)",
                   rationale: "Görünən CPU nüvəsi sayı", icon: "cpu", tier: .passive),
            Signal(name: "RAM", value: ramString(),
                   rationale: "Fiziki yaddaş həcmi", icon: "memorychip", tier: .passive),
            Signal(name: "Disk (cəmi)", value: diskTotal(),
                   rationale: "Cihazın ümumi yaddaşı", icon: "internaldrive", tier: .passive),
            Signal(name: "Disk (boş)", value: diskFree(),
                   rationale: "İstifadə edilməmiş yaddaş", icon: "internaldrive.fill", tier: .passive),
            Signal(name: "Batareya", value: "\(batteryLevel) · \(batteryState)",
                   rationale: "Şarj səviyyəsi və vəziyyəti", icon: "battery.75", tier: .passive),
            Signal(name: "Sistem uptime", value: uptimeStr(),
                   rationale: "Son yenidən başlamadan keçən vaxt", icon: "clock", tier: .passive),
            Signal(name: "İlk aktivasiya", value: firstActivation(),
                   rationale: "Bu proqramın ilk işə salınma tarixi (Keychain-də saxlanılır)", icon: "calendar.badge.clock", tier: .passive),
        ])
    }

    static func collectScreen() -> SignalCategory {
        let screen = UIScreen.main
        let bounds = screen.nativeBounds
        return SignalCategory(title: "Ekran", icon: "rectangle.on.rectangle", tier: .passive, signals: [
            Signal(name: "Həll qabiliyyəti", value: "\(Int(bounds.width))×\(Int(bounds.height)) px",
                   rationale: "Fiziki piksel ölçüsü", icon: "rectangle", tier: .passive),
            Signal(name: "Miqyas", value: "\(screen.nativeScale)×",
                   rationale: "Retina miqyas əmsalı", icon: "arrow.up.left.and.arrow.down.right", tier: .passive),
            Signal(name: "Parlaqlıq", value: String(format: "%.0f%%", screen.brightness * 100),
                   rationale: "Cari ekran parlaqlığı", icon: "sun.max", tier: .passive),
        ])
    }

    static func collectLocale() -> SignalCategory {
        let locale = Locale.current
        let tz = TimeZone.current
        let offsetSec = tz.secondsFromGMT()
        let offsetH = offsetSec / 3600
        let offsetM = abs(offsetSec % 3600) / 60
        let offsetStr = offsetM == 0 ? "UTC\(offsetH > 0 ? "+" : "")\(offsetH)" : "UTC+\(offsetH):\(String(format: "%02d", offsetM))"

        return SignalCategory(title: "Dil və Region", icon: "globe.europe.africa", tier: .passive, signals: [
            Signal(name: "Dil", value: Locale.preferredLanguages.first ?? "?",
                   rationale: "Üstünlük verilən dil", icon: "globe", tier: .passive),
            Signal(name: "Region", value: locale.region?.identifier ?? "?",
                   rationale: "Cihazın region parametri", icon: "mappin", tier: .passive),
            Signal(name: "Saat qurşağı", value: "\(tz.identifier) (\(offsetStr))",
                   rationale: "Cari saat qurşağı — istifadəçinin yerini göstərə bilər", icon: "clock.badge", tier: .passive),
            Signal(name: "Valyuta", value: locale.currency?.identifier ?? "?",
                   rationale: "Locale-a görə valyuta kodu", icon: "banknote", tier: .passive),
            Signal(name: "Ölçü sistemi", value: locale.measurementSystem == .metric ? "Metrik" : "Imperial",
                   rationale: "Metrik vs imperial", icon: "ruler", tier: .passive),
        ])
    }

    static func collectNetwork() -> SignalCategory {
        return SignalCategory(title: "Şəbəkə", icon: "wifi", tier: .passive, signals: [
            Signal(name: "Hostname", value: ProcessInfo.processInfo.hostName,
                   rationale: "Lokal hostname — adətən cihaz adı ilə eynidir", icon: "network", tier: .passive),
            Signal(name: "IP (WiFi)", value: wifiIP() ?? "Yoxdur",
                   rationale: "Lokal şəbəkə IPv4 ünvanı", icon: "wifi.circle", tier: .passive),
        ])
    }

    static func collectGPU() -> SignalCategory {
        return SignalCategory(title: "Qrafika", icon: "cpu.fill", tier: .passive, signals: [
            Signal(name: "GPU", value: gpuName(),
                   rationale: "Metal API-nin bildirdiyi GPU adı", icon: "memorychip.fill", tier: .passive),
        ])
    }

    static func collectAudio() -> SignalCategory {
        let session = AVAudioSession.sharedInstance()
        let output = session.currentRoute.outputs.map { $0.portName }.joined(separator: ", ")
        return SignalCategory(title: "Səs", icon: "speaker.wave.2", tier: .passive, signals: [
            Signal(name: "Çıxış", value: output.isEmpty ? "Yoxdur" : output,
                   rationale: "Aktiv audio çıxış cihazı", icon: "airpodspro", tier: .passive),
            Signal(name: "Səs səviyyəsi", value: String(format: "%.0f%%", session.outputVolume * 100),
                   rationale: "Sistem səs həcmi", icon: "speaker.wave.3", tier: .passive),
        ])
    }

    // MARK: Helpers

    private static func ramString() -> String {
        ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory)
    }

    private static func diskTotal() -> String {
        guard let a = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let v = a[.systemSize] as? Int64 else { return "?" }
        return ByteCountFormatter.string(fromByteCount: v, countStyle: .file)
    }

    private static func diskFree() -> String {
        guard let a = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let v = a[.systemFreeSize] as? Int64 else { return "?" }
        return ByteCountFormatter.string(fromByteCount: v, countStyle: .file)
    }

    private static func uptimeStr() -> String {
        let u = ProcessInfo.processInfo.systemUptime
        let h = Int(u) / 3600; let m = (Int(u) % 3600) / 60
        return "\(h) saat \(m) dəqiqə"
    }

    static func firstActivation() -> String {
        let key = "dr_first_launch_v1"
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        var res: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess,
           let d = res as? Data, let s = String(data: d, encoding: .utf8) { return s }
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let sq: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: now.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(sq as CFDictionary, nil)
        return now + " (bu gün)"
    }

    private static func wifiIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            ptr = interface.ifa_next
        }
        return address
    }

    private static func gpuName() -> String {
        return MTLCreateSystemDefaultDevice()?.name ?? "Bilinmir"
    }
}

struct AdvancedCollector {
    static func collectInstalledApps() -> SignalCategory {
        let apps: [(String, String)] = [
            ("WhatsApp",    "whatsapp://"),
            ("Telegram",    "tg://"),
            ("Instagram",   "instagram://"),
            ("X (Twitter)", "twitter://"),
            ("TikTok",      "tiktok://"),
            ("Discord",     "discord://"),
            ("YouTube",     "youtube://"),
            ("Netflix",     "nflx://"),
            ("Snapchat",    "snapchat://"),
            ("Gmail",       "googlegmail://"),
            ("Google Maps", "comgooglemaps://"),
            ("Spotify",     "spotify://"),
            ("ProtonMail",  "protonmail://"),
            ("GitHub",      "github://"),
            ("Notion",      "notion://"),
            ("Signal",      "sgnl://"),
            ("PayPal",      "paypal://"),
            ("Uber",        "uber://"),
            ("LinkedIn",    "linkedin://"),
            ("Pinterest",   "pinterest://"),
        ]

        let installed = apps.filter {
            UIApplication.shared.canOpenURL(URL(string: $0.1)!)
        }.map { $0.0 }

        let value = installed.isEmpty
            ? "Heç biri tapılmadı"
            : "\(installed.count)/\(apps.count): \(installed.joined(separator: ", "))"

        return SignalCategory(title: "Quraşdırılmış Tətbiqlər", icon: "square.grid.2x2", tier: .advanced, signals: [
            Signal(name: "Aşkar edilənlər", value: value,
                   rationale: "canOpenURL() ilə URL sxeması yoxlanılır — icazəsiz", icon: "apps.iphone", tier: .advanced),
            Signal(name: "Yüklənmə sayı", value: installCount(),
                   rationale: "Keychain silinmə zamanı təmizlənmir — yenidən yükləmə sayını izləyir", icon: "arrow.down.circle", tier: .advanced),
        ])
    }

    static func collectWebFingerprint() -> SignalCategory {
        return SignalCategory(title: "WebView Barmaq İzi", icon: "safari", tier: .advanced, signals: [
            Signal(name: "User Agent", value: webViewUA(),
                   rationale: "Gizli WKWebView-dan oxunan UA — cihaz sinfi və WebKit versiyasını aşkar edir", icon: "globe.badge.chevron.backward", tier: .advanced),
        ])
    }

    private static func installCount() -> String {
        let key = "dr_install_count_v1"
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        var res: AnyObject?
        var count = 1
        if SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess,
           let d = res as? Data,
           let s = String(data: d, encoding: .utf8),
           let n = Int(s) {
            count = n + 1
            SecItemDelete(q as CFDictionary)
        }
        let sq: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: "\(count)".data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(sq as CFDictionary, nil)
        return "\(count) dəfə"
    }

    private static func webViewUA() -> String {
        // Sync UA fetch via semaphore
        var ua = "Oxunmadı"
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let wv = WKWebView()
            wv.evaluateJavaScript("navigator.userAgent") { result, _ in
                if let s = result as? String { ua = s }
                sem.signal()
            }
        }
        sem.wait()
        return ua
    }
}

struct MotionCollector {
    static func collect() -> SignalCategory {
        let manager = CMMotionManager()
        var accel = "İcazə yoxdur"
        if manager.isAccelerometerAvailable {
            manager.startAccelerometerUpdates()
            Thread.sleep(forTimeInterval: 0.1)
            if let d = manager.accelerometerData {
                accel = String(format: "x=%.3f  y=%.3f  z=%.3f", d.acceleration.x, d.acceleration.y, d.acceleration.z)
            }
            manager.stopAccelerometerUpdates()
        }

        return SignalCategory(title: "Hərəkət Sensorları", icon: "gyroscope", tier: .passive, signals: [
            Signal(name: "Akselerometr", value: accel,
                   rationale: "3 oxlu sürətlənmə — icazəsiz oxunur", icon: "move.3d", tier: .passive),
        ])
    }
}

// MARK: - ViewModel

class RadarViewModel: ObservableObject {
    @Published var categories: [SignalCategory] = []
    @Published var generatedAt = ""
    @Published var selectedTier: Tier? = nil
    @Published var isLoading = false

    var filtered: [SignalCategory] {
        guard let t = selectedTier else { return categories }
        return categories.filter { $0.tier == t }
    }

    var totalSignals: Int { categories.reduce(0) { $0 + $1.signals.count } }

    func generate() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let cats: [SignalCategory] = [
                PassiveCollector.collectDevice(),
                PassiveCollector.collectScreen(),
                PassiveCollector.collectLocale(),
                PassiveCollector.collectNetwork(),
                PassiveCollector.collectAudio(),
                PassiveCollector.collectGPU(),
                MotionCollector.collect(),
                AdvancedCollector.collectInstalledApps(),
                AdvancedCollector.collectWebFingerprint(),
            ]
            let fmt = DateFormatter()
            fmt.dateFormat = "dd.MM.yyyy · HH:mm:ss"
            DispatchQueue.main.async {
                self.categories = cats
                self.generatedAt = fmt.string(from: Date())
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
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if vm.isLoading {
                    LoadingView()
                } else if vm.categories.isEmpty {
                    WelcomeView { vm.generate() }
                } else {
                    MainList(vm: vm)
                }
            }
            .navigationTitle("DeviceRadar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !vm.categories.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { vm.generate() }) {
                            Image(systemName: "arrow.clockwise")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .onAppear { vm.generate() }
    }
}

// MARK: Welcome

struct WelcomeView: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "4ADE80").opacity(0.2), Color(hex: "F87171").opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "4ADE80"), Color(hex: "FBBF24")],
                        startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 8) {
                Text("DeviceRadar")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Cihazın nəyi ifşa etdiyini gör")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Analiz et")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 220)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(hex: "4ADE80"), Color(hex: "22D3EE")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.black)
                .cornerRadius(14)
                .shadow(color: Color(hex: "4ADE80").opacity(0.4), radius: 12, y: 6)
            }
        }
        .padding()
    }
}

// MARK: Loading

struct LoadingView: View {
    @State private var angle = 0.0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 3)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "4ADE80"), Color(hex: "22D3EE")],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(angle))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            angle = 360
                        }
                    }
            }
            Text("Siqnallar toplanır...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: Main List

struct MainList: View {
    @ObservedObject var vm: RadarViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header stats
                StatsHeader(vm: vm)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Tier filter
                TierFilter(selected: $vm.selectedTier)
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                // Categories
                ForEach(vm.filtered) { cat in
                    CategoryCard(category: cat)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                // Footer
                Text("Tarix: \(vm.generatedAt)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
    }
}

// MARK: Stats Header

struct StatsHeader: View {
    @ObservedObject var vm: RadarViewModel

    var passiveCount: Int { vm.categories.filter { $0.tier == .passive }.flatMap { $0.signals }.count }
    var permCount: Int    { vm.categories.filter { $0.tier == .permissioned }.flatMap { $0.signals }.count }
    var advCount: Int     { vm.categories.filter { $0.tier == .advanced }.flatMap { $0.signals }.count }

    var body: some View {
        HStack(spacing: 10) {
            StatPill(value: passiveCount, label: "Passiv", color: Tier.passive.color)
            StatPill(value: permCount,    label: "İcazəli", color: Tier.permissioned.color)
            StatPill(value: advCount,     label: "Gizli",   color: Tier.advanced.color)
        }
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: Tier Filter

struct TierFilter: View {
    @Binding var selected: Tier?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Hamısı", icon: "square.grid.2x2", color: .primary,
                           isSelected: selected == nil) { selected = nil }
                ForEach(Tier.allCases, id: \.self) { tier in
                    FilterChip(label: tier.rawValue, icon: tier.icon, color: tier.color,
                               isSelected: selected == tier) {
                        selected = selected == tier ? nil : tier
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption).fontWeight(.medium)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(isSelected ? color.opacity(0.2) : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1))
        }
    }
}

// MARK: Category Card

struct CategoryCard: View {
    let category: SignalCategory
    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(category.tier.color.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: category.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(category.tier.color)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.title)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("\(category.signals.count) siqnal · \(category.tier.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }

            if expanded {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(Array(category.signals.enumerated()), id: \.element.id) { idx, signal in
                        SignalRow(signal: signal)
                        if idx < category.signals.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: Signal Row

struct SignalRow: View {
    let signal: Signal
    @State private var showRationale = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: signal.icon)
                    .font(.system(size: 13))
                    .foregroundColor(signal.tier.color)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(signal.value)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }

                Spacer()

                Button(action: { withAnimation { showRationale.toggle() } }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if showRationale {
                Text(signal.rationale)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 50)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
