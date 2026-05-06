import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.xeo.timeblocking", category: "DataTransferManager")

struct DataBackup: Codable {
    let version: String
    let exportDate: Date
    let timeBlocks: [TimeBlockDTO]
    let templates: [ScheduleTemplateDTO]
    let checklistItems: [BlockChecklistItemDTO]
    let brainDumpItems: [BrainDumpItemDTO]
    let preferences: AppPreferencesDTO?
}

struct TimeBlockDTO: Codable {
    let id: UUID
    let title: String
    let notes: String?
    let startDate: Date
    let endDate: Date
    let category: TimeBlockCategory
    let status: TimeBlockStatus
    let isPinned: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    let templateID: UUID?
}

struct ScheduleTemplateDTO: Codable {
    let id: UUID
    let name: String
    let notes: String?
    let defaultStartHour: Int
    let defaultDurationMinutes: Int
    let weekdayMask: Int
    let category: TimeBlockCategory
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
}

struct BlockChecklistItemDTO: Codable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    let timeBlockID: UUID?
}

struct BrainDumpItemDTO: Codable {
    let id: UUID
    let title: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

struct AppPreferencesDTO: Codable {
    let id: String
    let defaultBlockDurationMinutes: Int
    let dayStartHour: Int
    let firstWeekday: Weekday
    let notificationsEnabled: Bool?
    let notificationLeadTimeMinutes: Int?
    let showsCompletedBlocks: Bool?
    let appTheme: AppTheme?
    let selectedColorTheme: AppColorTheme?
    let isImmersive: Bool?
    let hapticsEnabled: Bool?
    let appLockEnabled: Bool?
    let hasSeenOnboarding: Bool
    let createdAt: Date
    let updatedAt: Date
}

@MainActor
final class DataTransferManager {
    static let shared = DataTransferManager()
    
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    func exportData(modelContext: ModelContext) throws -> Data {
        logger.info("Starting data export...")
        
        let blocks = try modelContext.fetch(FetchDescriptor<TimeBlock>())
        let templates = try modelContext.fetch(FetchDescriptor<ScheduleTemplate>())
        let items = try modelContext.fetch(FetchDescriptor<BlockChecklistItem>())
        let brainDump = try modelContext.fetch(FetchDescriptor<BrainDumpItem>())
        let prefs = try modelContext.fetch(FetchDescriptor<AppPreferences>()).first
        
        let backup = DataBackup(
            version: "1.1",
            exportDate: .now,
            timeBlocks: blocks.map { block in
                TimeBlockDTO(
                    id: block.id,
                    title: block.title,
                    notes: block.notes,
                    startDate: block.startDate,
                    endDate: block.endDate,
                    category: block.category,
                    status: block.status,
                    isPinned: block.isPinned,
                    sortOrder: block.sortOrder,
                    createdAt: block.createdAt,
                    updatedAt: block.updatedAt,
                    templateID: block.template?.id
                )
            },
            templates: templates.map { template in
                ScheduleTemplateDTO(
                    id: template.id,
                    name: template.name,
                    notes: template.notes,
                    defaultStartHour: template.defaultStartHour,
                    defaultDurationMinutes: template.defaultDurationMinutes,
                    weekdayMask: template.weekdayMask,
                    category: template.category,
                    sortOrder: template.sortOrder,
                    createdAt: template.createdAt,
                    updatedAt: template.updatedAt
                )
            },
            checklistItems: items.map { item in
                BlockChecklistItemDTO(
                    id: item.id,
                    title: item.title,
                    isCompleted: item.isCompleted,
                    sortOrder: item.sortOrder,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    timeBlockID: item.timeBlock?.id
                )
            },
            brainDumpItems: brainDump.map { item in
                BrainDumpItemDTO(
                    id: item.id,
                    title: item.title,
                    notes: item.notes,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            preferences: prefs.map { p in
                AppPreferencesDTO(
                    id: p.id,
                    defaultBlockDurationMinutes: p.defaultBlockDurationMinutes,
                    dayStartHour: p.dayStartHour,
                    firstWeekday: p.firstWeekday,
                    notificationsEnabled: p.notificationsEnabled,
                    notificationLeadTimeMinutes: p.notificationLeadTimeMinutes,
                    showsCompletedBlocks: p.showsCompletedBlocks,
                    appTheme: p.appTheme,
                    selectedColorTheme: p.selectedColorTheme,
                    isImmersive: p.isImmersive,
                    hapticsEnabled: p.hapticsEnabled,
                    appLockEnabled: p.appLockEnabled,
                    hasSeenOnboarding: p.hasSeenOnboarding,
                    createdAt: p.createdAt,
                    updatedAt: p.updatedAt
                )
            }
        )
        
        let data = try jsonEncoder.encode(backup)
        logger.info("Data export completed successfully.")
        return data
    }
    
    func importData(data: Data, modelContext: ModelContext) throws {
        logger.info("Starting data import...")
        let backup = try jsonDecoder.decode(DataBackup.self, from: data)
        
        // 1. Import Templates
        var templateMap: [UUID: ScheduleTemplate] = [:]
        for dto in backup.templates {
            let fetchDescriptor = FetchDescriptor<ScheduleTemplate>(predicate: #Predicate { $0.id == dto.id })
            let existing = try modelContext.fetch(fetchDescriptor).first
            
            let template = existing ?? ScheduleTemplate(id: dto.id, name: dto.name)
            template.name = dto.name
            template.notes = dto.notes
            template.defaultStartHour = dto.defaultStartHour
            template.defaultDurationMinutes = dto.defaultDurationMinutes
            template.weekdayMask = dto.weekdayMask
            template.category = dto.category
            template.sortOrder = dto.sortOrder
            template.createdAt = dto.createdAt
            template.updatedAt = dto.updatedAt
            
            if existing == nil {
                modelContext.insert(template)
            }
            templateMap[dto.id] = template
        }
        
        // 2. Import TimeBlocks
        var blockMap: [UUID: TimeBlock] = [:]
        for dto in backup.timeBlocks {
            let fetchDescriptor = FetchDescriptor<TimeBlock>(predicate: #Predicate { $0.id == dto.id })
            let existing = try modelContext.fetch(fetchDescriptor).first
            
            let block = existing ?? TimeBlock(
                id: dto.id,
                title: dto.title,
                startDate: dto.startDate,
                endDate: dto.endDate
            )
            block.title = dto.title
            block.notes = dto.notes
            block.startDate = dto.startDate
            block.endDate = dto.endDate
            block.category = dto.category
            block.status = dto.status
            block.isPinned = dto.isPinned
            block.sortOrder = dto.sortOrder
            block.createdAt = dto.createdAt
            block.updatedAt = dto.updatedAt
            
            if let templateID = dto.templateID {
                block.template = templateMap[templateID]
            }
            
            if existing == nil {
                modelContext.insert(block)
            }
            blockMap[dto.id] = block
        }
        
        // 3. Import Checklist Items
        for dto in backup.checklistItems {
            let fetchDescriptor = FetchDescriptor<BlockChecklistItem>(predicate: #Predicate { $0.id == dto.id })
            let existing = try modelContext.fetch(fetchDescriptor).first
            
            let item = existing ?? BlockChecklistItem(id: dto.id, title: dto.title)
            item.title = dto.title
            item.isCompleted = dto.isCompleted
            item.sortOrder = dto.sortOrder
            item.createdAt = dto.createdAt
            item.updatedAt = dto.updatedAt
            
            if let blockID = dto.timeBlockID {
                item.timeBlock = blockMap[blockID]
            }
            
            if existing == nil {
                modelContext.insert(item)
            }
        }
        
        // 4. Import Brain Dump Items
        for dto in backup.brainDumpItems {
            let fetchDescriptor = FetchDescriptor<BrainDumpItem>(predicate: #Predicate { $0.id == dto.id })
            let existing = try modelContext.fetch(fetchDescriptor).first
            
            let item = existing ?? BrainDumpItem(id: dto.id, title: dto.title)
            item.title = dto.title
            item.notes = dto.notes
            item.createdAt = dto.createdAt
            item.updatedAt = dto.updatedAt
            
            if existing == nil {
                modelContext.insert(item)
            }
        }
        
        // 5. Import Preferences
        if let dto = backup.preferences {
            let fetchDescriptor = FetchDescriptor<AppPreferences>(predicate: #Predicate { $0.id == dto.id })
            let existing = try modelContext.fetch(fetchDescriptor).first
            
            let prefs = existing ?? AppPreferences(id: dto.id)
            prefs.defaultBlockDurationMinutes = dto.defaultBlockDurationMinutes
            prefs.dayStartHour = dto.dayStartHour
            prefs.firstWeekday = dto.firstWeekday
            prefs.notificationsEnabled = dto.notificationsEnabled
            prefs.notificationLeadTimeMinutes = dto.notificationLeadTimeMinutes
            prefs.showsCompletedBlocks = dto.showsCompletedBlocks
            prefs.appTheme = dto.appTheme
            prefs.selectedColorTheme = dto.selectedColorTheme
            prefs.isImmersive = dto.isImmersive
            prefs.hapticsEnabled = dto.hapticsEnabled
            prefs.appLockEnabled = dto.appLockEnabled
            prefs.hasSeenOnboarding = dto.hasSeenOnboarding
            prefs.createdAt = dto.createdAt
            prefs.updatedAt = dto.updatedAt
            
            if existing == nil {
                modelContext.insert(prefs)
            }
        }
        
        try modelContext.save()
        logger.info("Data import completed successfully.")
    }
}
