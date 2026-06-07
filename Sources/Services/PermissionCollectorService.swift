//
//  PermissionCollectorService.swift
//  DeviceRadar
//
//  Created by DeviceRadar Team.
//  Copyright © 2026 LethalLethes. All rights reserved.
//

import Foundation
import Photos
import Contacts
import EventKit

/// Collects device signals that require user permissions.
/// 
/// Handles permission checks gracefully:
/// - If authorized: returns actual data
/// - If not determined: requests permission
/// - If denied: shows user-friendly message
class PermissionCollectorService: DataCollectorService {
    private let logger = Logger.shared
    
    func collectSignals() -> [SignalCategory] {
        logger.debug("Starting permission-based signal collection")
        return [
            collectPhotos(),
            collectContacts(),
            collectCalendar()
        ]
    }
    
    // MARK: - Photos/Library
    
    private func collectPhotos() -> SignalCategory {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            let photos = PHAsset.fetchAssets(with: .image, options: nil).count
            let videos = PHAsset.fetchAssets(with: .video, options: nil).count
            let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).count
            
            let permissionLevel = status == .limited ? "Məhdud" : "Tam"
            
            return SignalCategory(
                title: "Fotolar",
                icon: "photo.stack",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Şəkillər",
                        value: "\(photos)",
                        rationale: "Foto sayı",
                        icon: "photo",
                        tier: .permissioned
                    ),
                    Signal(
                        name: "Videolar",
                        value: "\(videos)",
                        rationale: "Video sayı",
                        icon: "video",
                        tier: .permissioned
                    ),
                    Signal(
                        name: "Albumlar",
                        value: "\(albums)",
                        rationale: "Albom sayı",
                        icon: "rectangle.stack",
                        tier: .permissioned
                    ),
                    Signal(
                        name: "İcazə",
                        value: permissionLevel,
                        rationale: "İcazə növü",
                        icon: "checkmark.shield",
                        tier: .permissioned
                    )
                ]
            )
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
            return SignalCategory(
                title: "Fotolar",
                icon: "photo.stack",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Status",
                        value: "İcazə verilmədi — yenidən bas",
                        rationale: "Tələb edilir",
                        icon: "questionmark.circle",
                        tier: .permissioned
                    )
                ]
            )
            
        default:
            return SignalCategory(
                title: "Fotolar",
                icon: "photo.stack",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Status",
                        value: "İcazə verilməyib",
                        rationale: "Parametrlərdən açın",
                        icon: "xmark.circle",
                        tier: .permissioned
                    )
                ]
            )
        }
    }
    
    // MARK: - Contacts
    
    private func collectContacts() -> SignalCategory {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            let store = CNContactStore()
            let keys = [
                CNContactGivenNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey
            ] as [CNKeyDescriptor]
            
            var total = 0
            var withPhone = 0
            var withEmail = 0
            
            do {
                let contacts = try store.unifiedContacts(
                    matching: NSPredicate(value: true),
                    keysToFetch: keys
                )
                total = contacts.count
                withPhone = contacts.filter { !$0.phoneNumbers.isEmpty }.count
                withEmail = contacts.filter { !$0.emailAddresses.isEmpty }.count
            } catch {
                logger.error("Failed to fetch contacts: \(error.localizedDescription)")
            }
            
            return SignalCategory(
                title: "Kontaktlar",
                icon: "person.2",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Cəmi",
                        value: "\(total)",
                        rationale: "Ümumi kontakt sayı",
                        icon: "person.2",
                        tier: .permissioned
                    ),
                    Signal(
                        name: "Telefonlu",
                        value: "\(withPhone)",
                        rationale: "Nömrəsi olan kontaktlar",
                        icon: "phone",
                        tier: .permissioned
                    ),
                    Signal(
                        name: "Emailli",
                        value: "\(withEmail)",
                        rationale: "E-maili olan kontaktlar",
                        icon: "envelope",
                        tier: .permissioned
                    )
                ]
            )
            
        case .notDetermined:
            CNContactStore().requestAccess(for: .contacts) { _, _ in }
            return SignalCategory(
                title: "Kontaktlar",
                icon: "person.2",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Status",
                        value: "İcazə verilmədi — yenidən bas",
                        rationale: "",
                        icon: "questionmark.circle",
                        tier: .permissioned
                    )
                ]
            )
            
        default:
            return SignalCategory(
                title: "Kontaktlar",
                icon: "person.2",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Status",
                        value: "İcazə verilməyib",
                        rationale: "Parametrlərdən açın",
                        icon: "xmark.circle",
                        tier: .permissioned
                    )
                ]
            )
        }
    }
    
    // MARK: - Calendar
    
    private func collectCalendar() -> SignalCategory {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized, .fullAccess:
            let calendars = store.calendars(for: .event)
            let reminders = store.calendars(for: .reminder)
            
            return SignalCategory(
                title: "Təqvim",
                icon: "calendar",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Təqvim sayı",
                        value: "\(calendars.count)",
                        rationale: "Bütün hesablar üzrə",
                        icon: "calendar",
                        tier: .permissioned
                    ),
                    Signal(
                        name: "Xatırlatmalar",
                        value: "\(reminders.count)",
                        rationale: "Xatırlatma siyahıları",
                        icon: "list.bullet",
                        tier: .permissioned
                    )
                ]
            )
            
        case .notDetermined:
            if #available(iOS 17.0, *) {
                store.requestFullAccessToEvents { _, _ in }
            } else {
                store.requestAccess(to: .event) { _, _ in }
            }
            return SignalCategory(
                title: "Təqvim",
                icon: "calendar",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Status",
                        value: "İcazə verilmədi — yenidən bas",
                        rationale: "",
                        icon: "questionmark.circle",
                        tier: .permissioned
                    )
                ]
            )
            
        default:
            return SignalCategory(
                title: "Təqvim",
                icon: "calendar",
                tier: .permissioned,
                signals: [
                    Signal(
                        name: "Status",
                        value: "İcazə verilməyib",
                        rationale: "Parametrlərdən açın",
                        icon: "xmark.circle",
                        tier: .permissioned
                    )
                ]
            )
        }
    }
}
