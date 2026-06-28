import Foundation
import CoreData

struct EventModel {
    var title: String
    var time: Date
    var location: String
    var isImportant: Bool
    var shouldRemind: Bool
    var createdAt: Date
    var isDraft: Bool
}

extension EventModel {

    func toEntity(context: NSManagedObjectContext) -> EventEntity {
        let entity = EventEntity(context: context)
        entity.title = self.title
        entity.time = self.time
        entity.location = self.location
        entity.isImportant = self.isImportant
        entity.shouldRemind = self.shouldRemind
        entity.createdAt = self.createdAt
        entity.isDraft = isDraft
        return entity
    }

    static func fromEntity(_ entity: EventEntity) -> EventModel {
        return EventModel(
            title: entity.title ?? "",
            time: entity.time ?? Date(),
            location: entity.location ?? "",
            isImportant: entity.isImportant,
            shouldRemind: entity.shouldRemind,
            createdAt: entity.createdAt ?? Date(),
            isDraft: entity.isDraft
        )
    }
}

