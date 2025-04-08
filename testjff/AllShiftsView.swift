import SwiftUI
import Firebase

struct AllShiftsView: View {
    @State private var shifts: [String: [WorkShift]] = [:]
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var isLoading = true
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                VStack(spacing: 20) {
                    // Месяц и кнопки навигации
                    HStack {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        
                        Text(formatMonthYear(date: selectedMonth))
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Дни недели
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Календарь
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(getDaysInMonth(), id: \.self) { date in
                            DayCell(
                                date: date,
                                selectedDate: $selectedDate,
                                shifts: shifts[formatDateKey(date: date)] ?? [],
                                isCurrentMonth: isSameMonth(date1: date, date2: selectedMonth)
                            )
                            .onTapGesture {
                                selectedDate = date
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Список смен на выбранную дату
                    if let selectedDate = selectedDate {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Смены на \(formatFullDate(date: selectedDate))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Группировка смен по зонам
                            ForEach(getZonesForDate(selectedDate), id: \.self) { zone in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(zone)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal)
                                    
                                    ForEach(getShiftsForDateAndZone(selectedDate, zone)) { shift in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(shift.employeeName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal)
                                            
                                            ShiftCard(shift: shift)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.top)
                    }
                }
            }
        }
        .navigationTitle("Все смены")
        .onAppear {
            fetchAllShifts()
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            fetchAllShifts()
        }
    }
    
    private func getDaysInMonth() -> [Date] {
        let calendar = Calendar.current
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offsetDays = (firstWeekday + 5) % 7
        let startDate = calendar.date(byAdding: .day, value: -offsetDays, to: firstDayOfMonth)!
        
        var dates: [Date] = []
        var currentDate = startDate
        
        for _ in 0..<42 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    private func formatMonthYear(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).capitalized
    }
    
    private func formatFullDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatDateKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func isSameMonth(date1: Date, date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
    }
    
    private func getZonesForDate(_ date: Date) -> [String] {
        let dateKey = formatDateKey(date: date)
        let shiftsForDate = shifts[dateKey] ?? []
        let zones = Set(shiftsForDate.map { $0.zone }).sorted()
        return zones
    }
    
    private func getShiftsForDateAndZone(_ date: Date, _ zone: String) -> [WorkShift] {
        let dateKey = formatDateKey(date: date)
        let shiftsForDate = shifts[dateKey] ?? []
        return shiftsForDate
            .filter { $0.zone == zone }
            .sorted { $0.startTime.dateValue() < $1.startTime.dateValue() }
    }
    
    private func fetchAllShifts() {
        let db = Firestore.firestore()
        
        // Получаем первый и последний день месяца
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        
        db.collection("shifts")
            .whereField("date", isGreaterThanOrEqualTo: formatDateKey(date: monthStart))
            .whereField("date", isLessThanOrEqualTo: formatDateKey(date: monthEnd))
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    print("Ошибка при загрузке смен: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                var newShifts: [String: [WorkShift]] = [:]
                
                for document in documents {
                    let data = document.data()
                    
                    guard let startTime = data["startTime"] as? Timestamp,
                          let endTime = data["endTime"] as? Timestamp,
                          let date = data["date"] as? String else {
                        continue
                    }
                    
                    let shift = WorkShift(
                        id: document.documentID,
                        employeeName: data["employeeName"] as? String ?? "Неизвестно",
                        specialty: data["specialty"] as? String ?? "Не указано",
                        startTime: startTime,
                        endTime: endTime,
                        breakTime: data["breakTime"] as? Int ?? 0,
                        zone: data["zone"] as? String ?? "Неизвестно",
                        date: date,
                        status: data["status"] as? String ?? "assigned",
                        employeeId: data["employeeId"] as? String
                    )
                    
                    newShifts[date, default: []].append(shift)
                }
                
                self.shifts = newShifts
            }
    }
}
