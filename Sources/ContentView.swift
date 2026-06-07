import SwiftUI
import UIKit
import Security

// MARK: - Model

struct Signal: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let icon: String
}

struct Category: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let signals: [Signal]
}

// MARK: - Collectors

struct DeviceCollector {
    static func collect() -> Category {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let batteryLevel = device.batteryLevel >= 0
            ? "\(Int(device.batteryLevel * 100))%"
            : "Bilinmir"

        let batteryState: String
        switch device.batteryState {
        case .charging:  batteryState = "Şarj olunur"
        case .full:      batteryState = "Dolu"
        case .unplugged: batteryState = "Batareya"
        default:         batteryState = "Bilinmir"
        }

        let signals: [Signal] = [
            Signal(name: "Model",          value: device.model,                          icon: "iphone"),
            Signal(name: "Adı",            value: device.name,                           icon: "person.crop.circle"),
            Signal(name: "iOS versiyası",  value: device.systemVersion,                  icon: "gear"),
            Signal(name: "CPU nüvəsi",     value: "\(ProcessInfo.processInfo.processorCount)", icon: "cpu"),
            Signal(name: "RAM",            value: ramString(),                            icon: "memorychip"),
            Signal(name: "Disk (Cəmi)",    value: totalDiskSpace(),                       icon: "internaldrive"),
            Signal(name: "Disk (Boş)",     value: freeDiskSpace(),                        icon: "internaldrive.fill"),
            Signal(name: "Batareya",       value: "\(batteryLevel) · \(batteryState)",   icon: "battery.75"),
            Signal(name: "Sistem uptime",  value: uptimeString(),                         icon: "clock"),
            Signal(name: "İlk aktivasiya", value: firstActivationDate(),                  icon: "calendar.badge.clock"),
        ]

        return Category(title: "Cihaz", icon: "iphone.gen1", color: .blue, signals: signals)
    }

    private static func totalDiskSpace() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let size = attrs[.systemSize] as? Int64 else { return "?" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private static func freeDiskSpace() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let free = attrs[.systemFreeSize] as? Int64 else { return "?" }
        return ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }

    private static func ramString() -> String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private static func uptimeString() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours   = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)s \(minutes)d"
    }

    private static func firstActivationDate() -> String {
        let key = "device_first_launch"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let dateStr = String(data: data, encoding: .utf8) {
            return dateStr
        }

        let now = DateFormatter.localizedString(
            from: Date(), dateStyle: .medium, timeStyle: .short
        )
        let saveQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: now.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(saveQuery as CFDictionary, nil)
        return now + " (bu gün)"
    }
}

struct ScreenCollector {
    static func collect() -> Category {
        let screen = UIScreen.main
        let bounds = screen.nativeBounds

        let signals: [Signal] = [
            Signal(name: "Piksel",    value: "\(Int(bounds.width))×\(Int(bounds.height))", icon: "rectangle"),
            Signal(name: "Miqyas",    value: "\(screen.nativeScale)x",                     icon: "arrow.up.left.and.arrow.down.right"),
            Signal(name: "Parlaqlıq",value: String(format: "%.0f%%", screen.brightness * 100), icon: "sun.max"),
        ]

        return Category(title: "Ekran", icon: "rectangle.on.rectangle", color: .purple, signals: signals)
    }
}

struct LocaleCollector {
    static func collect() -> Category {
        let locale   = Locale.current
        let tz       = TimeZone.current
        let calendar = Calendar.current

        let signals: [Signal] = [
            Signal(name: "Dil",          value: Locale.preferredLanguages.first ?? "?",       icon: "globe"),
            Signal(name: "Region",       value: locale.region?.identifier ?? "?",             icon: "mappin"),
            Signal(name: "Saat qurşağı", value: "\(tz.identifier) (UTC\(tzOffset(tz)))",      icon: "clock.badge"),
            Signal(name: "Təqvim",       value: "\(calendar.identifier)",                      icon: "calendar"),
            Signal(name: "Para",         value: locale.currency?.identifier ?? "?",            icon: "banknote"),
        ]

        return Category(title: "Dil & Region", icon: "globe.europe.africa", color: .green, signals: signals)
    }

    private static func tzOffset(_ tz: TimeZone) -> String {
        let seconds = tz.secondsFromGMT()
        let hours   = seconds / 3600
        let mins    = abs(seconds % 3600) / 60
        return mins == 0 ? "\(hours)" : "\(hours):\(String(format: "%02d", mins))"
    }
}

struct NetworkCollector {
    static func collect() -> Category {
        let signals: [Signal] = [
            Signal(name: "Hostname", value: ProcessInfo.processInfo.hostName, icon: "network"),
        ]
        return Category(title: "Şəbəkə", icon: "wifi", color: .orange, signals: signals)
    }
}

// MARK: - ViewModel

class ReportViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var generatedAt: String = ""

    func generate() {
        categories = [
            DeviceCollector.collect(),
            ScreenCollector.collect(),
            LocaleCollector.collect(),
            NetworkCollector.collect(),
        ]
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        generatedAt = formatter.string(from: Date())
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var vm = ReportViewModel()

    var body: some View {
        NavigationView {
            Group {
                if vm.categories.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Cihaz məlumatlarını toplamaq üçün düyməyə bas")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button(action: { vm.generate() }) {
                            Label("Analiz et", systemImage: "play.fill")
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            Label("Tarix: \(vm.generatedAt)", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ForEach(vm.categories) { category in
                            CategorySection(category: category)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("DeviceRadar")
            .toolbar {
                if !vm.categories.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { vm.generate() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear { vm.generate() }
        }
    }
}

struct CategorySection: View {
    let category: Category

    var body: some View {
        Section {
            ForEach(category.signals) { signal in
                SignalRow(signal: signal, color: category.color)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text(category.title)
            }
        }
    }
}

struct SignalRow: View {
    let signal: Signal
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: signal.icon)
                .frame(width: 28)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(signal.value)
                    .font(.system(.body, design: .monospaced))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
