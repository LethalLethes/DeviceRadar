//
//  AdvancedCollectorService.swift
//  DeviceRadar
//
//  Created by DeviceRadar Team.
//  Copyright © 2026 LethalLethes. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import Security

/// Collects advanced fingerprinting signals using side-channel techniques.
/// 
/// These are clever uses of public APIs:
/// - URL scheme probing to detect installed apps
/// - WebView User-Agent to fingerprint device class
/// - Keychain persistence across app reinstalls
class AdvancedCollectorService: DataCollectorService {
    private let logger = Logger.shared
    
    func collectSignals() -> [SignalCategory] {
        logger.debug("Starting advanced signal collection")
        return [
            collectInstalledApps(),
            collectWebViewUserAgent()
        ]
    }
    
    // MARK: - Installed Apps Detection
    
    private func collectInstalledApps() -> SignalCategory {
        let appsList: [(String, String)] = [
            ("WhatsApp", "whatsapp://"),
            ("Telegram", "tg://"),
            ("Instagram", "instagram://"),
            ("X", "twitter://"),
            ("TikTok", "tiktok://"),
            ("Discord", "discord://"),
            ("YouTube", "youtube://"),
            ("Netflix", "nflx://"),
            ("Snapchat", "snapchat://"),
            ("Gmail", "googlegmail://"),
            ("Google Maps", "comgooglemaps://"),
            ("Spotify", "spotify://"),
            ("ProtonMail", "protonmail://"),
            ("GitHub", "github://"),
            ("Signal", "sgnl://"),
            ("Notion", "notion://"),
            ("PayPal", "paypal://"),
            ("LinkedIn", "linkedin://"),
            ("Uber", "uber://"),
            ("Pinterest", "pinterest://")
        ]
        
        let foundApps = appsList.filter { name, scheme in
            guard let url = URL(string: scheme) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }.map { $0.0 }
        
        let foundValue = foundApps.isEmpty
            ? "Heç biri tapılmadı"
            : "\(foundApps.count)/\(appsList.count): \(foundApps.joined(separator: ", "))"
        
        let installCount = getInstallCount()
        
        return SignalCategory(
            title: "Quraşdırılmış Tətbiqlər",
            icon: "square.grid.2x2",
            tier: .advanced,
            signals: [
                Signal(
                    name: "Tapılanlar",
                    value: foundValue,
                    rationale: "canOpenURL() — icazəsiz",
                    icon: "apps.iphone",
                    tier: .advanced
                ),
                Signal(
                    name: "Yüklənmə sayı",
                    value: installCount,
                    rationale: "Keychain silmədə qalır",
                    icon: "arrow.down.circle",
                    tier: .advanced
                )
            ]
        )
    }
    
    // MARK: - WebView User-Agent
    
    private func collectWebViewUserAgent() -> SignalCategory {
        let userAgent = getWebViewUserAgent()
        
        return SignalCategory(
            title: "WebView Barmaq İzi",
            icon: "safari",
            tier: .advanced,
            signals: [
                Signal(
                    name: "User Agent",
                    value: userAgent,
                    rationale: "Gizli WKWebView — cihaz sinfi aşkar edilir",
                    icon: "globe.badge.chevron.backward",
                    tier: .advanced
                )
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    private func getInstallCount() -> String {
        let key = "dr_install_count_v2"
        
        // Try to read existing count from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        var result: AnyObject?
        var count = 1
        
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let str = String(data: data, encoding: .utf8),
           let n = Int(str) {
            count = n + 1
            SecItemDelete(query as CFDictionary)
        }
        
        // Store updated count in Keychain
        let storeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: "\(count)".data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(storeQuery as CFDictionary, nil)
        
        return "\(count) dəfə"
    }
    
    private func getWebViewUserAgent() -> String {
        var userAgent = "Oxunmadı"
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            let webView = WKWebView(frame: .zero)
            webView.evaluateJavaScript("navigator.userAgent") { result, error in
                if let ua = result as? String {
                    userAgent = ua
                }
                semaphore.signal()
            }
        }
        
        let timeout = DispatchTime.now() + .seconds(3)
        _ = semaphore.wait(timeout: timeout)
        
        return userAgent
    }
}
