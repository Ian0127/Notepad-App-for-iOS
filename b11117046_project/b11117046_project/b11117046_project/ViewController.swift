//
//  ViewController.swift
//  b11117046_project
//
//  Created by eb209 on 2025/12/15.
//
import UIKit
import CoreData

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

 

    @IBOutlet weak var tableView: UITableView!
    
    var events: [EventModel] = []
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        loadEvents()
        setupSortButton()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationArrived),
            name: .notificationDelivered,
            object: nil
        )

    }
    @objc func notificationArrived() {
        print("收到通知，立即檢查提醒狀態")
        checkPendingNotifications()
    }

    
    @objc func appDidBecomeActive() {
        checkPendingNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.checkPendingNotifications()
            }
    }


    // 資料筆數
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }

    // 顯示每一列內容
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let event = events[indexPath.row]

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath) as? EventTableViewCell else {
            fatalError("無法轉型為 EventTableViewCell")
        }

        cell.titlelabel.text = event.title.isEmpty ? "（草稿）" : event.title
        if event.isDraft {
            cell.draftIcon.image = UIImage(systemName: "pencil")
            cell.draftIcon.tintColor = .systemGray
        } else {
            cell.draftIcon.image = nil
        }


        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        cell.timelabel.text = formatter.string(from: event.time)

        // 重要性顯示
        if event.isImportant {
            cell.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
            cell.importantIcon.image = UIImage(systemName: "star.fill")
            cell.importantIcon.tintColor = .systemOrange
        } else {
            cell.backgroundColor = .clear
            cell.importantIcon.image = nil
        }

        // 提醒鈴鐺顯示
        if event.shouldRemind {
            cell.reminderIcon.image = UIImage(systemName: "bell.fill")
            cell.reminderIcon.tintColor = .systemBlue
        } else {
            cell.reminderIcon.image = nil
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditEventViewController") as? EditEventViewController {
            let event = events[indexPath.row]
            editVC.event = event
            editVC.editIndex = indexPath.row
            
            let latestEvent = self.events[indexPath.row]
            editVC.event?.shouldRemind = latestEvent.shouldRemind


            // 更新資料
            editVC.onSave = { [weak self] (updatedEvent: EventModel, index: Int) -> Void in
                guard let self = self else { return }

                self.events[index] = updatedEvent
                DispatchQueue.main.async {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                }
                let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                let predicate = NSPredicate(format: "createdAt == %@", updatedEvent.createdAt as NSDate)
                request.predicate = predicate
                request.fetchLimit = 1

                do {
                    if let existing = try self.context.fetch(request).first {
                        existing.title = updatedEvent.title
                        existing.time = updatedEvent.time
                        existing.location = updatedEvent.location
                        existing.isImportant = updatedEvent.isImportant
                        existing.shouldRemind = updatedEvent.shouldRemind
                        existing.isDraft = false

                        try self.context.save()
                        print("更新成功")
                    }
                } catch {
                    print("更新失敗：\(error)")
                }

                self.tableView.reloadData()
            }


            // 刪除資料
            editVC.onDelete = { (index: Int) in
                let event = self.events[index]
                
                self.events.remove(at: index)
                
                let notificationID = "event-\(event.createdAt.timeIntervalSince1970)"
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])

                let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                let predicate = NSPredicate(format: "createdAt == %@", event.createdAt as NSDate)
                request.predicate = predicate
                request.fetchLimit = 1


                do {
                    if let entityToDelete = try self.context.fetch(request).first {
                        self.context.delete(entityToDelete)
                        try self.context.save()
                        print("刪除成功")
                    }
                    // 4. 重新載入資料，避免殘影或資料不同步
                    self.loadEvents()
                } catch {
                    print("刪除失敗：\(error)")
                }
            }
            navigationController?.pushViewController(editVC, animated: true)

        }
    }

    func loadEvents() {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        do {
            let entities = try context.fetch(request)
            self.events = entities.map { EventModel.fromEntity($0) }
            tableView.reloadData()
        } catch {
            print("讀取 Core Data 失敗：\(error)")
        }
    }

    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(
            withIdentifier: "EditEventViewController"
        ) as? EditEventViewController {

            // 先建立草稿 Event
            let draftEvent = EventModel(
                title: "",
                time: Date(),
                location: "",
                isImportant: false,
                shouldRemind: false,
                createdAt: Date(),
                isDraft: true
            )

            // 存進 Core Data（草稿）
            draftEvent.toEntity(context: self.context)
            try? self.context.save()
            
            // 加進 events
            self.events.append(draftEvent)
            self.tableView.reloadData()


            //  傳進編輯頁
            editVC.event = draftEvent
            editVC.editIndex = self.events.count - 1

            editVC.onSave = { [weak self] updatedEvent, index in
                guard let self = self else { return }

                self.events[index] = updatedEvent

                let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                request.predicate = NSPredicate(format: "createdAt == %@", updatedEvent.createdAt as NSDate)
                request.fetchLimit = 1

                if let entity = try? self.context.fetch(request).first {
                    entity.title = updatedEvent.title
                    entity.time = updatedEvent.time
                    entity.location = updatedEvent.location
                    entity.isImportant = updatedEvent.isImportant
                    entity.shouldRemind = updatedEvent.shouldRemind
                    entity.isDraft = false
                    try? self.context.save()
                }

                self.tableView.reloadData()
            }


            editVC.onDelete = { [weak self] index in
                guard let self = self else { return }
                let event = self.events[index]

                let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                request.predicate = NSPredicate(format: "createdAt == %@", event.createdAt as NSDate)
                request.fetchLimit = 1

                if let entity = try? self.context.fetch(request).first {
                    self.context.delete(entity)
                    try? self.context.save()
                }

                self.events.remove(at: index)
                self.tableView.reloadData()
            }

            navigationController?.pushViewController(editVC, animated: true)
        }
    }
    
    func setupSortButton() {
        let sortButton = UIBarButtonItem(title: "排序", style: .plain, target: self, action: #selector(showSortMenu))
        navigationItem.leftBarButtonItem = sortButton
    }

    @objc func showSortMenu() {
        let alert = UIAlertController(title: "排序方式", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "依提醒時間", style: .default, handler: { _ in
            self.sortEvents(by: .time)
        }))
        
        alert.addAction(UIAlertAction(title: "重要性優先", style: .default, handler: { _ in
            self.sortEvents(by: .importance)
        }))

        alert.addAction(UIAlertAction(title: "依建立順序", style: .default, handler: { _ in
            self.sortEvents(by: .createdAt)
        }))

        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    enum SortOption {
        case time
        case importance
        case createdAt
    }

    func sortEvents(by option: SortOption) {
        switch option {
        case .time:
            let reminderEvents = events.filter { $0.shouldRemind }
                .sorted { $0.time < $1.time }

            let noReminderEvents = events.filter { !$0.shouldRemind }
                .sorted { $0.createdAt < $1.createdAt }

            events = reminderEvents + noReminderEvents

        case .importance:
            // 有重要性的事件（依建立時間排序）
            let importantEvents = events
                .filter { $0.isImportant }
                .sorted { $0.createdAt < $1.createdAt }

            // 沒有重要性的事件（依建立時間排序）
            let normalEvents = events
                .filter { !$0.isImportant }
                .sorted { $0.createdAt < $1.createdAt }

            // 合併（重要的在上面）
            events = importantEvents + normalEvents

        case .createdAt:
            events.sort { $0.createdAt < $1.createdAt }
        }
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPendingNotifications()
    }
    
    func checkPendingNotifications() {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }

            center.getDeliveredNotifications { delivered in
                var needReloadIndexPaths: [IndexPath] = []
                var hasChanges = false   // 宣告在 for 外面（關鍵）

                for i in 0..<self.events.count {
                    let event = self.events[i]

                    // 草稿不處理
                    if event.isDraft { continue }

                    let id = "event-\(event.createdAt.timeIntervalSince1970)"
                    let isPending = requests.contains { $0.identifier == id }

                    if event.shouldRemind && !isPending {

                        // 更新 memory
                        self.events[i].shouldRemind = false

                        //更新 Core Data
                        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                        request.predicate = NSPredicate(
                            format: "createdAt == %@", event.createdAt as NSDate
                        )
                        request.fetchLimit = 1

                        if let entity = try? self.context.fetch(request).first {
                            entity.shouldRemind = false
                            hasChanges = true
                        }

                        // 移除已送達通知
                        center.removeDeliveredNotifications(withIdentifiers: [id])

                        // 記錄需要更新的 cell
                        needReloadIndexPaths.append(IndexPath(row: i, section: 0))

                        print("自動關閉提醒：\(event.title)")
                    }
                }

                // 只 save 一次（for 結束後）
                if hasChanges {
                    try? self.context.save()
                }

                // 只更新必要的 cell（不 loadEvents）
                if !needReloadIndexPaths.isEmpty {
                    DispatchQueue.main.async {
                        self.tableView.reloadRows(
                            at: needReloadIndexPaths,
                            with: .automatic
                        )
                    }
                }
            }
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadEvents()
    }


}



