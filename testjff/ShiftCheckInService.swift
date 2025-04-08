//import Firebase
//import FirebaseAuth
//import CoreLocation
//
//class ShiftCheckInService: ObservableObject {
//    static let shared = ShiftCheckInService()
//    private let db = Firestore.firestore()
//    private let locationManager = CLLocationManager()
//    
//    @Published var currentShift: WorkShift?
//    @Published var checkInStatus: CheckInStatus = .noShift
//    
//    enum CheckInStatus: Equatable {
//        case noShift
//        case waiting
//        case canCheckIn
//        case checkedIn
//        case completed
//        case missed
//        case error(String)
//        
//        static func == (lhs: CheckInStatus, rhs: CheckInStatus) -> Bool {
//            switch (lhs, rhs) {
//            case (.noShift, .noShift),
//                 (.waiting, .waiting),
//                 (.canCheckIn, .canCheckIn),
//                 (.checkedIn, .checkedIn),
//                 (.completed, .completed),
//                 (.missed, .missed):
//                return true
//            case (.error(let lhsMessage), .error(let rhsMessage)):
//                return lhsMessage == rhsMessage
//            default:
//                return false
//            }
//        }
//    }
//    
//    func checkCurrentShift() {
//        guard let userId = Auth.auth().currentUser?.uid else { return }
//        
//        let today = Date()
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd"
//        let todayString = formatter.string(from: today)
//        
//        db.collection("shifts")
//            .whereField("employeeId", isEqualTo: userId)
//            .whereField("date", isEqualTo: todayString)
//            .getDocuments { [weak self] snapshot, error in
//                if let error = error {
//                    print("❌ Ошибка получения смены: \(error.localizedDescription)")
//                    self?.checkInStatus = .error("Ошибка загрузки данных")
//                    return
//                }
//                
//                guard let document = snapshot?.documents.first else {
//                    self?.checkInStatus = .noShift
//                    return
//                }
//                
//                let data = document.data()
//                guard let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
//                      let endTime = (data["endTime"] as? Timestamp)?.dateValue() else {
//                    self?.checkInStatus = .error("Некорректные данные смены")
//                    return
//                }
//                
//                let shift = WorkShift(
//                    id: document.documentID,
//                    employeeName: data["employeeName"] as? String ?? "Неизвестно",
//                    specialty: data["specialty"] as? String ?? "Не указано",
//                    startTime: Timestamp(date: startTime),
//                    endTime: Timestamp(date: endTime),
//                    breakTime: data["breakTime"] as? Int ?? 0,
//                    zone: data["zone"] as? String ?? "Неизвестно",
//                    date: todayString,
//                    status: data["status"] as? String ?? "scheduled",
//                    employeeId: userId
//                )
//                
//                self?.currentShift = shift
//                self?.updateCheckInStatus(shift: shift)
//            }
//    }
//    
//    private func updateCheckInStatus(shift: WorkShift) {
//        let now = Date()
//        let fifteenMinutesBeforeStart = Calendar.current.date(byAdding: .minute, value: -15, to: shift.startTime.dateValue())!
//        
//        if shift.status == "completed" {
//            checkInStatus = .completed
//        } else if shift.status == "started" {
//            checkInStatus = .checkedIn
//        } else if now > shift.endTime.dateValue() {
//            checkInStatus = .missed
//        } else if now >= fifteenMinutesBeforeStart && now <= shift.endTime.dateValue() {
//            checkInStatus = .canCheckIn
//        } else if now < fifteenMinutesBeforeStart {
//            checkInStatus = .waiting
//        } else {
//            checkInStatus = .noShift
//        }
//    }
//    
//    func checkIn(completion: @escaping (Bool, String?) -> Void) {
//        guard let shift = currentShift else {
//            completion(false, "Нет активной смены")
//            return
//        }
//        
//        let now = Date()
//        let fifteenMinutesBeforeStart = Calendar.current.date(byAdding: .minute, value: -15, to: shift.startTime.dateValue())!
//        
//        guard now >= fifteenMinutesBeforeStart && now <= shift.endTime.dateValue() else {
//            completion(false, "Невозможно отметиться в данное время")
//            return
//        }
//        
//        let checkInData: [String: Any] = [
//            "status": "started",
//            "checkIn": [
//                "time": Timestamp(date: now),
//                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
//            ]
//        ]
//        
//        db.collection("shifts").document(shift.id).updateData(checkInData) { error in
//            if let error = error {
//                completion(false, "Ошибка отметки: \(error.localizedDescription)")
//            } else {
//                self.currentShift?.status = "started"
//                self.checkInStatus = .checkedIn
//                completion(true, nil)
//            }
//        }
//    }
//    
//    func checkOut(completion: @escaping (Bool, String?) -> Void) {
//        guard let shift = currentShift else {
//            completion(false, "Нет активной смены")
//            return
//        }
//        
//        let now = Date()
//        guard now >= shift.startTime.dateValue() else {
//            completion(false, "Невозможно завершить смену до её начала")
//            return
//        }
//        
//        let checkOutData: [String: Any] = [
//            "status": "completed",
//            "checkOut": [
//                "time": Timestamp(date: now),
//                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
//            ]
//        ]
//        
//        db.collection("shifts").document(shift.id).updateData(checkOutData) { error in
//            if let error = error {
//                completion(false, "Ошибка завершения смены: \(error.localizedDescription)")
//            } else {
//                self.currentShift?.status = "completed"
//                self.checkInStatus = .completed
//                completion(true, nil)
//            }
//        }
//    }
//    
//    // Функции для менеджера
//    func getTodayShifts(completion: @escaping ([WorkShift]) -> Void) {
//        let today = Date()
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd"
//        let todayString = formatter.string(from: today)
//        
//        db.collection("shifts")
//            .whereField("date", isEqualTo: todayString)
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    print("❌ Ошибка получения смен: \(error.localizedDescription)")
//                    completion([])
//                    return
//                }
//                
//                let shifts = snapshot?.documents.compactMap { document -> WorkShift? in
//                    let data = document.data()
//                    guard let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
//                          let endTime = (data["endTime"] as? Timestamp)?.dateValue() else {
//                        return nil
//                    }
//                    
//                    return WorkShift(
//                        id: document.documentID,
//                        employeeName: data["employeeName"] as? String ?? "Неизвестно",
//                        specialty: data["specialty"] as? String ?? "Не указано",
//                        startTime: Timestamp(date: startTime),
//                        endTime: Timestamp(date: endTime),
//                        breakTime: data["breakTime"] as? Int ?? 0,
//                        zone: data["zone"] as? String ?? "Неизвестно",
//                        date: todayString,
//                        status: data["status"] as? String ?? "scheduled",
//                        employeeId: data["employeeId"] as? String
//                    )
//                } ?? []
//                
//                completion(shifts)
//            }
//    }
//    
//    func managerCheckIn(shiftId: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let managerId = Auth.auth().currentUser?.uid else {
//            completion(false, "Менеджер не авторизован")
//            return
//        }
//        
//        let checkInData: [String: Any] = [
//            "status": "started",
//            "managerCheckIn": [
//                "time": Timestamp(date: Date()),
//                "managerId": managerId
//            ]
//        ]
//        
//        db.collection("shifts").document(shiftId).updateData(checkInData) { error in
//            if let error = error {
//                completion(false, "Ошибка отметки: \(error.localizedDescription)")
//            } else {
//                completion(true, nil)
//            }
//        }
//    }
//    
//    func managerCheckOut(shiftId: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let managerId = Auth.auth().currentUser?.uid else {
//            completion(false, "Менеджер не авторизован")
//            return
//        }
//        
//        let checkOutData: [String: Any] = [
//            "status": "completed",
//            "managerCheckOut": [
//                "time": Timestamp(date: Date()),
//                "managerId": managerId
//            ]
//        ]
//        
//        db.collection("shifts").document(shiftId).updateData(checkOutData) { error in
//            if let error = error {
//                completion(false, "Ошибка завершения смены: \(error.localizedDescription)")
//            } else {
//                completion(true, nil)
//            }
//        }
//    }
//    
//    // Функции для отмены действий
//    func cancelCheckIn(shiftId: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let managerId = Auth.auth().currentUser?.uid else {
//            completion(false, "Менеджер не авторизован")
//            return
//        }
//        
//        let cancelData: [String: Any] = [
//            "status": "scheduled",
//            "cancelCheckIn": [
//                "time": Timestamp(date: Date()),
//                "managerId": managerId
//            ]
//        ]
//        
//        db.collection("shifts").document(shiftId).updateData(cancelData) { error in
//            if let error = error {
//                completion(false, "Ошибка отмены отметки: \(error.localizedDescription)")
//            } else {
//                completion(true, nil)
//            }
//        }
//    }
//    
//    func cancelCheckOut(shiftId: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let managerId = Auth.auth().currentUser?.uid else {
//            completion(false, "Менеджер не авторизован")
//            return
//        }
//        
//        let cancelData: [String: Any] = [
//            "status": "started",
//            "cancelCheckOut": [
//                "time": Timestamp(date: Date()),
//                "managerId": managerId
//            ]
//        ]
//        
//        db.collection("shifts").document(shiftId).updateData(cancelData) { error in
//            if let error = error {
//                completion(false, "Ошибка отмены завершения: \(error.localizedDescription)")
//            } else {
//                completion(true, nil)
//            }
//        }
//    }
//}
