//
//  EditEventViewController.swift
//  b11117046_project
//
//  Created by eb209 on 2025/12/16.
//

import UIKit
import UserNotifications
import CoreData

class EditEventViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var locationTextField: UITextView!
    
    @IBOutlet weak var importantSwitch: UISwitch!
    @IBOutlet weak var reminderSwitch: UISwitch!
    
    @IBOutlet weak var deleteButton: UIButton!
        var event: EventModel? // 傳入的事件資料
        var editIndex: Int? // 新增事件時使用（只有事件，沒有 index）
        var onAdd: ((EventModel) -> Void)?
        var onSave: ((EventModel, Int) -> Void)?
        var onDelete: ((Int) -> Void)?


        override func viewDidLoad() {
            super.viewDidLoad()
            
            titleTextField.addTarget(
                self,
                action: #selector(draftDidChange),
                for: .editingChanged
            )
            locationTextField.delegate = self
            
            reminderSwitch.isOn = false // 預設為關閉提醒

            if let event = event {
                // 編輯模式
                titleTextField.text = event.title
                datePicker.date = event.time
                locationTextField.text = event.location
                importantSwitch.isOn = event.isImportant
                deleteButton.isHidden = false
            }
            
            // 標題輸入框加邊框
            titleTextField.layer.borderColor = UIColor.lightGray.cgColor
            titleTextField.layer.borderWidth = 1.0
            titleTextField.layer.cornerRadius = 8.0
            titleTextField.clipsToBounds = true

            
            locationTextField.layer.borderColor = UIColor.lightGray.cgColor  // 邊框顏色
            locationTextField.layer.borderWidth = 1.0                        // 邊框寬度
            locationTextField.layer.cornerRadius = 8.0                       // 圓角半徑
            locationTextField.clipsToBounds = true                           // 裁切超出範圍

        }
        
        @objc func draftDidChange() {
            guard let event = event else { return }

            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

            let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "createdAt == %@", event.createdAt as NSDate)
            request.fetchLimit = 1

            if let entity = try? context.fetch(request).first {
                entity.title = titleTextField.text ?? ""
                entity.location = locationTextField.text ?? ""
                
                // ➤ 僅在尚未儲存過才標記草稿
                if entity.isDraft {
                    entity.isDraft = true
                }

                try? context.save()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            draftDidChange()
        }
    
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard let title = titleTextField.text, !title.isEmpty,
                  let location = locationTextField.text, !location.isEmpty else { return }

            let now = Date()
            let selectedTime = datePicker.date
            let createdAt = event?.createdAt ?? Date() // 只在第一次產生

            // 防呆：提醒時間不得等於或早於現在時間
            if reminderSwitch.isOn && selectedTime <= now {
                let alert = UIAlertController(
                    title: "時間錯誤",
                    message: "提醒時間必須設定在未來。",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }

            // 建立新的 EventModel
            let newEvent = EventModel(
                title: title,
                time: selectedTime,
                location: location,
                isImportant: importantSwitch.isOn,
                shouldRemind: reminderSwitch.isOn,
                createdAt: createdAt,
                isDraft: false
            )

            // 通知排程 function
            func scheduleNotification(title: String, location: String, time: Date, createdAt: Date) {
                let content = UNMutableNotificationContent()
                content.title = "行事曆提醒"
                content.body = "標題：\(title)\n內文：\(location)"
                content.sound = .default

                let triggerDate = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: time
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                let id = "event-\(createdAt.timeIntervalSince1970)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request)
            }

            // 分流：編輯 / 新增
            if let editIndex = editIndex {
                // ===== 編輯模式 =====
                let context = (UIApplication.shared.delegate as! AppDelegate)
                    .persistentContainer.viewContext

                let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                request.predicate = NSPredicate(
                    format: "createdAt == %@", createdAt as NSDate
                )
                request.fetchLimit = 1

                if let entity = try? context.fetch(request).first {
                    entity.title = newEvent.title
                    entity.time = newEvent.time
                    entity.location = newEvent.location
                    entity.isImportant = newEvent.isImportant
                    entity.shouldRemind = newEvent.shouldRemind
                    entity.isDraft = false
                    try? context.save()
                }


                let notificationID = "event-\(createdAt.timeIntervalSince1970)"

                // 關鍵：先刪舊通知（不管時間有沒有變）
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: [notificationID])

                // 如果提醒是開的 → 重新排通知（新標題 / 新內文）
                if reminderSwitch.isOn {
                    scheduleNotification(
                        title: title,
                        location: location,
                        time: selectedTime,
                        createdAt: createdAt
                    )
                }

                onSave?(newEvent, editIndex)

            } else {
                // ===== 新增模式 =====
                if reminderSwitch.isOn {
                    scheduleNotification(
                        title: title,
                        location: location,
                        time: selectedTime,
                        createdAt: createdAt
                    )
                }

                onAdd?(newEvent)
            }

            navigationController?.popViewController(animated: true)
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard let editIndex = editIndex else { return }
        onDelete?(editIndex)
        navigationController?.popViewController(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let event = event else { return }

        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt == %@", event.createdAt as NSDate)
        request.fetchLimit = 1

        if let entity = try? context.fetch(request).first {
            reminderSwitch.isOn = entity.shouldRemind
        }
    }

}
