//
//  PersistenceController.swift
//  b11117046_project
//
//  Created by eb209 on 2025/12/17.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "b11117046_project") // 這裡名稱要跟你的 .xcdatamodeld 一樣
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
    }
}
