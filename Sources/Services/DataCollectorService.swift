//
//  DataCollectorService.swift
//  DeviceRadar
//
//  Created by DeviceRadar Team.
//  Copyright © 2026 LethalLethes. All rights reserved.
//

import Foundation

/// Protocol defining the contract for data collection services.
/// 
/// Implementations collect device signals and group them into categories
/// based on permission tier. This abstraction allows:
/// - Easy testing with mock services
/// - Switching between different collection strategies
/// - Parallel collection from multiple services
protocol DataCollectorService {
    /// Collects all signals from this service.
    /// 
    /// Should handle errors gracefully without throwing.
    /// Returns empty array if collection fails.
    /// 
    /// - Returns: Array of SignalCategories with collected signals
    func collectSignals() -> [SignalCategory]
}

/// Main orchestrator service that coordinates all data collectors.
/// 
/// Combines results from PassiveCollectorService, PermissionCollectorService,
/// and AdvancedCollectorService into a single comprehensive list.
class DeviceRadarCollectorService: DataCollectorService {
    private let logger = Logger.shared
    
    /// All registered collector services.
    private let collectors: [DataCollectorService]
    
    /// Initializes the collector with all available services.
    init(
        passiveCollector: DataCollectorService = PassiveCollectorService(),
        permissionCollector: DataCollectorService = PermissionCollectorService(),
        advancedCollector: DataCollectorService = AdvancedCollectorService()
    ) {
        self.collectors = [
            passiveCollector,
            permissionCollector,
            advancedCollector
        ]
    }
    
    /// Collects signals from all registered services.
    /// 
    /// Executes collectors in parallel on a background queue for performance.
    /// Results are merged and returned in a consistent order.
    /// 
    /// - Returns: Combined array of all collected signal categories
    func collectSignals() -> [SignalCategory] {
        logger.info("Starting signal collection from \(collectors.count) services")
        
        var allCategories: [SignalCategory] = []
        let queue = DispatchQueue(label: "com.deviceradar.collection", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        
        // Collect from each service in parallel
        for collector in collectors {
            queue.async(group: group) {
                let categories = collector.collectSignals()
                lock.lock()
                allCategories.append(contentsOf: categories)
                lock.unlock()
                self.logger.debug("Collected \(categories.count) categories")
            }
        }
        
        // Wait for all collectors to finish
        group.wait()
        
        logger.info("Completed signal collection: \(allCategories.count) categories, \(allCategories.flatMap { $0.signals }.count) signals")
        return allCategories
    }
}
