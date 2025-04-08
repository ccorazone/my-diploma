import Foundation
import FirebaseFirestore
import Firebase

/*
struct Shift: Identifiable {
    var id: String
    var date: Date
    var startTime: Date
    var endTime: Date
    var employeeIds: [String] // Список ID сотрудников
}*/
struct WorkShift: Identifiable, Equatable {
    let id: String
    let employeeName: String
    let specialty: String
    let startTime: Timestamp
    let endTime: Timestamp
    let breakTime: Int?
    let breakStartTime: Timestamp?
    let breakEndTime: Timestamp?
    let zone: String
    let date: String
    var status: String = "assigned" // assigned, open, pending_exchange
    var employeeId: String?
    
    init(id: String,
         employeeName: String,
         specialty: String,
         startTime: Timestamp,
         endTime: Timestamp,
         breakTime: Int?,
         breakStartTime: Timestamp? = nil,
         breakEndTime: Timestamp? = nil,
         zone: String,
         date: String,
         status: String = "assigned",
         employeeId: String? = nil) {
        self.id = id
        self.employeeName = employeeName
        self.specialty = specialty
        self.startTime = startTime
        self.endTime = endTime
        self.breakTime = breakTime
        self.breakStartTime = breakStartTime
        self.breakEndTime = breakEndTime
        self.zone = zone
        self.date = date
        self.status = status
        self.employeeId = employeeId
    }
    
    var duration: TimeInterval {
        return endTime.dateValue().timeIntervalSince(startTime.dateValue())
    }
    
    static func == (lhs: WorkShift, rhs: WorkShift) -> Bool {
        return lhs.id == rhs.id &&
               lhs.employeeName == rhs.employeeName &&
               lhs.specialty == rhs.specialty &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.breakTime == rhs.breakTime &&
               lhs.breakStartTime == rhs.breakStartTime &&
               lhs.breakEndTime == rhs.breakEndTime &&
               lhs.zone == rhs.zone &&
               lhs.date == rhs.date &&
               lhs.status == rhs.status &&
               lhs.employeeId == rhs.employeeId
    }
}
