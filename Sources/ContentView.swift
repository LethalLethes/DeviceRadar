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

// MARK: - Passive

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
            s("Disk (boş)",    diskFree(),                                  "Boş yaddaş",                       "internaldrive.fill"),
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
        let m = CMMotionManager()
        var accel = "Mövcud deyil"
        if m.isAccelerometerAvailable {
            m.startAccelerometerUpdates()
            Thread.sleep(forTimeInterval: 0.15)
            if let d = m.accelerometerData {
                accel = String(format: "x=%.3f  y=%.3f  z=%.3f", d.acceleration.x, d.acceleration.y, d.acceleration.z)
            }
            m.stopAccelerometerUpdates()
        }
        return cat("Sensor", "gyroscope", .passive, [
            s("Akselerometr", accel, "3 oxlu sürətlənmə — icazəsiz", "move.3d"),
        ])
    }

    // Shorthand builders
    static func cat(_ title: String, _ icon: String, _ tier: Tier, _ signals: [Signal]) -> SignalCategory {
        SignalCategory(title: title, icon: icon, tier: tier, signals: signals)
    }
    static func s(_ name: String, _ value: String, _ rationale: String, _ icon: String) -> Signal {
        Signal(name: name, value: value, rationale: rationale, icon: icon, tier: .passive)
    }

    // Helpers
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
        func ps(_ n: String, _ v: String, _ r: String, _ i: String) -> Signal {
            Signal(name: n, value: v, rationale: r, icon: i, tier: .permissioned)
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            let photos = PHAsset.fetchAssets(with: .image, options: nil).count
            let videos = PHAsset.fetchAssets(with: .video, options: nil).count
            let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).count
            return SignalCategory(title: "Fotolar", icon: "photo.stack", tier: .permissioned, signals: [
                ps("Şəkillər",  "\(photos)",                              "Foto sayı",              "photo"),
                ps("Videolar",  "\(videos)",                              "Video sayı",             "video"),
                ps("Albumlar",  "\(albums)",                              "Albom sayı",             "rectangle.stack"),
                ps("İcazə",     status == .limited ? "Məhdud" : "Tam",   "İcazə növü",             "checkmark.shield"),
            ])
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
            return SignalCategory(title: "Fotolar", icon: "photo.stack", tier: .permissioned,
                                  signals: [ps("Status", "İcazə verilmədi — yenidən bas", "Tələb edilir", "questionmark.circle")])
        default:
            return SignalCategory(title: "Fotolar", icon: "photo.stack", tier: .permissioned,
                                  signals: [ps("Status", "İcazə verilməyib", "Parametrlərdən açın", "xmark.circle")])
        }
    }

    static func contacts() -> SignalCategory {
        func cs(_ n: String, _ v: String, _ r: String, _ i: String) -> Signal {
            Signal(name: n, value: v, rationale: r, icon: i, tier: .permissioned)
        }
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            let store = CNContactStore()
            let keys = [CNContactGivenNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            var total = 0; var withPhone = 0; var withEmail = 0
            if let contacts = try? store.unifiedContacts(matching: NSPredicate(value: true), keysToFetch: keys) {
                total = contacts.count
                withPhone = contacts.filter { !$0.phoneNumbers.isEmpty }.count
                withEmail = contacts.filter { !$0.emailAddresses.isEmpty }.count
            }
            return SignalCategory(title: "Kontaktlar", icon: "person.2", tier: .permissioned, signals: [
                cs("Cəmi",          "\(total)",     "Ümumi kontakt sayı",      "person.2"),
                cs("Telefonlu",     "\(withPhone)", "Nömrəsi olan kontaktlar", "phone"),
                cs("Emailli",       "\(withEmail)", "E-maili olan kontaktlar", "envelope"),
            ])
        case .notDetermined:
            CNContactStore().requestAccess(for: .contacts) { _, _ in }
            return SignalCategory(title: "Kontaktlar", icon: "person.2", tier: .permissioned,
                                  signals: [cs("Status", "İcazə verilmədi — yenidən bas", "", "questionmark.circle")])
        default:
            return SignalCategory(title: "Kontaktlar", icon: "person.2", tier: .permissioned,
                                  signals: [cs("Status", "İcazə verilməyib", "Parametrlərdən açın", "xmark.circle")])
        }
    }

    static func calendar() -> SignalCategory {
        func es(_ n: String, _ v: String, _ r: String, _ i: String) -> Signal {
            Signal(name: n, value: v, rationale: r, icon: i, tier: .permissioned)
        }
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            let cals = store.calendars(for: .event)
            let remCals = store.calendars(for: .reminder)
            return SignalCategory(title: "Təqvim", icon: "calendar", tier: .permissioned, signals: [
                es("Təqvim sayı",   "\(cals.count)",    "Bütün hesablar üzrə",  "calendar"),
                es("Xatırlatmalar", "\(remCals.count)", "Xatırlatma siyahıları","list.bullet"),
            ])
        case .notDetermined:
            store.requestFullAccessToEvents { _, _ in }
            return SignalCategory(title: "Təqvim", icon: "calendar", tier: .permissioned,
                                  signals: [es("Status", "İcazə verilmədi — yenidən bas", "", "questionmark.circle")])
        default:
            return SignalCategory(title: "Təqvim", icon: "calendar", tier: .permissioned,
                                  signals: [es("Status", "İcazə verilməyib", "Parametrlərdən açın", "xmark.circle")])
        }
    }
}

// MARK: - Advanced Collector

struct AdvancedCollector {
    static func collectAll() -> [SignalCategory] {
        [apps(), webView()]
    }

    static func apps() -> SignalCategory {
        let list: [(String, String)] = [
            ("WhatsApp","whatsapp://"), ("Telegram","tg://"), ("Instagram","instagram://"),
            ("X","twitter://"), ("TikTok","tiktok://"), ("Discord","discord://"),
            ("YouTube","youtube://"), ("Netflix","nflx://"), ("Snapchat","snapchat://"),
            ("Gmail","googlegmail://"), ("Google Maps","comgooglemaps://"), ("Spotify","spotify://"),
            ("ProtonMail","protonmail://"), ("GitHub","github://"), ("Signal","sgnl://"),
            ("Notion","notion://"), ("PayPal","paypal://"), ("LinkedIn","linkedin://"),
            ("Uber","uber://"), ("Pinterest","pinterest://"),
        ]
        let found = list.filter { UIApplication.shared.canOpenURL(URL(string: $0.1)!) }.map { $0.0 }
        let val = found.isEmpty ? "Heç biri tapılmadı" : "\(found.count)/\(list.count): \(found.joined(separator: ", "))"
        return SignalCategory(title: "Quraşdırılmış Tətbiqlər", icon: "square.grid.2x2", tier: .advanced, signals: [
            Signal(name: "Tapılanlar",    value: val,            rationale: "canOpenURL() — icazəsiz", icon: "apps.iphone",      tier: .advanced),
            Signal(name: "Yüklənmə sayı",value: installCount(), rationale: "Keychain silmədə qalır", icon: "arrow.down.circle", tier: .advanced),
        ])
    }

    static func webView() -> SignalCategory {
        return SignalCategory(title: "WebView Barmaq İzi", icon: "safari", tier: .advanced, signals: [
            Signal(name: "User Agent", value: getUA(),
                   rationale: "Gizli WKWebView — cihaz sinfi aşkar edilir", icon: "globe.badge.chevron.backward", tier: .advanced),
        ])
    }

    private static func installCount() -> String {
        let key = "dr_install_count_v2"
        let q: [String:Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key, kSecReturnData as String: true,
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        var res: AnyObject?; var count = 1
        if SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess,
           let d = res as? Data, let str = String(data: d, encoding: .utf8), let n = Int(str) {
            count = n + 1; SecItemDelete(q as CFDictionary)
        }
        let sq: [String:Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrAccount as String: key,
                                 kSecValueData as String: "\(count)".data(using: .utf8)!,
                                 kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        SecItemAdd(sq as CFDictionary, nil)
        return "\(count) dəfə"
    }

    private static func getUA() -> String {
        var ua = "Oxunmadı"
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let wv = WKWebView(frame: .zero)
            wv.evaluateJavaScript("navigator.userAgent") { r, _ in
                if let str = r as? String { ua = str }
                sem.signal()
            }
        }
        _ = sem.wait(timeout: .now() + 3)
        return ua
    }
}

// MARK: - ViewModel

class RadarViewModel: ObservableObject {
    @Published var categories: [SignalCategory] = []
    @Published var generatedAt = ""
    @Published var selectedTier: Tier? = nil
    @Published var isLoading = false

    var filtered: [SignalCategory] {
        selectedTier == nil ? categories : categories.filter { $0.tier == selectedTier }
    }
    func count(_ tier: Tier) -> Int {
        categories.filter { $0.tier == tier }.flatMap { $0.signals }.count
    }

    func generate() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var cats = PassiveCollector.collectAll()
            cats += PermissionCollector.collectAll()
            cats += AdvancedCollector.collectAll()
            let fmt = DateFormatter(); fmt.dateFormat = "dd.MM.yyyy · HH:mm:ss"
            DispatchQueue.main.async {
                self.categories = cats
                self.generatedAt = fmt.string(from: Date())
                self.isLoading = false
            }
        }
    }
}

// MARK: - App Root

struct ContentView: View {
    @StateObject private var vm = RadarViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                if vm.isLoading {
                    LoadingView()
                } else {
                    MainList(vm: vm)
                }
            }
            .navigationTitle("DeviceRadar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.generate() } label: {
                        Image(systemName: "arrow.clockwise").fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear { vm.generate() }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var rot = 0.0
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 3).frame(width: 56, height: 56)
                Circle().trim(from: 0, to: 0.25)
                    .stroke(LinearGradient(colors: [Color(hex:"4ADE80"), Color(hex:"22D3EE")],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(rot))
                    .onAppear { withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { rot = 360 } }
            }
            Text("Siqnallar toplanır...").font(.subheadline).foregroundColor(.secondary)
        }
    }
}

// MARK: - Main List

struct MainList: View {
    @ObservedObject var vm: RadarViewModel
    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    StatPill(value: vm.count(.passive),      label: "Passiv",  color: Tier.passive.color)
                    StatPill(value: vm.count(.permissioned), label: "İcazəli", color: Tier.permissioned.color)
                    StatPill(value: vm.count(.advanced),     label: "Gizli",   color: Tier.advanced.color)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "Hamısı", icon: "square.grid.2x2", color: .primary,
                                   isSelected: vm.selectedTier == nil) { vm.selectedTier = nil }
                        ForEach(Tier.allCases, id: \.self) { t in
                            FilterChip(label: t.rawValue, icon: t.icon, color: t.color,
                                       isSelected: vm.selectedTier == t) {
                                vm.selectedTier = vm.selectedTier == t ? nil : t
                            }
                        }
                    }.padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            ForEach(vm.filtered) { cat in
                CategorySection(category: cat)
            }

            Section {
                Text("Tarix: \(vm.generatedAt)")
                    .font(.caption2).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: Int; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)").font(.system(.headline, design: .rounded)).fontWeight(.bold)
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String; let icon: String; let color: Color; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption).fontWeight(.medium)
            }
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(isSelected ? color.opacity(0.2) : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1))
        }
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let category: SignalCategory
    @State private var expanded = true
    var body: some View {
        Section {
            if expanded {
                ForEach(category.signals) { signal in
                    SignalRow(signal: signal)
                }
            }
        } header: {
            Button { withAnimation(.spring(response: 0.3)) { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(category.tier.color.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: category.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(category.tier.color)
                    }
                    Text(category.title)
                        .font(.system(.subheadline, design: .rounded)).fontWeight(.semibold)
                    Spacer()
                    Text("\(category.signals.count)").font(.caption2).foregroundColor(.secondary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .textCase(nil)
            }
        }
    }
}

// MARK: - Signal Row

struct SignalRow: View {
    let signal: Signal
    @State private var showInfo = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: signal.icon)
                    .font(.system(size: 13))
                    .foregroundColor(signal.tier.color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.name).font(.caption).foregroundColor(.secondary)
                    Text(signal.value)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(4)
                }
                Spacer()
                if !signal.rationale.isEmpty {
                    Button { withAnimation { showInfo.toggle() } } label: {
                        Image(systemName: "info.circle").font(.caption).foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            if showInfo && !signal.rationale.isEmpty {
                Text(signal.rationale)
                    .font(.caption2).foregroundColor(.secondary)
                    .padding(.leading, 34).padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
    }
}
