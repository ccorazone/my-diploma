import SwiftUI
import Firebase
import FirebaseAuth

struct EmployeeShiftsView: View {
    let employeeName: String
    @State private var shifts: [String: [WorkShift]] = [:]
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var isLoading = true
    @State private var shiftDays: Set<Int> = []
    @State private var selectedShift: WorkShift?
    @State private var showEditShiftSheet = false
    @State private var pendingExchanges: [String] = [] // IDs of shifts pending exchange
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ScrollView {
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
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        let shiftsForDate = shifts[formatDateKey(date: selectedDate)] ?? []
                        if shiftsForDate.isEmpty {
                            Text("Нет смен на этот день")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(shiftsForDate) { shift in
                                ShiftCard(
                                    shift: shift,
                                    showActions: true,
                                    onEdit: {
                                        handleEditTap(shift)
                                    },
                                    onDelete: {
                                        confirmDelete(shift)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .navigationTitle("Смены \(employeeName)")
        .sheet(isPresented: $showEditShiftSheet) {
            if let shift = selectedShift {
                EditShiftView(shift: shift) {
                    fetchShifts(for: selectedMonth)
                    selectedShift = nil
                    showEditShiftSheet = false
                }
            }
        }
        .onChange(of: selectedShift) { shift in
            if shift != nil {
                showEditShiftSheet = true
            }
        }
        .onAppear {
            fetchShifts(for: selectedMonth)
            fetchPendingExchanges()
        }

        .alert(isPresented: $showAlert) {
            Alert(title: Text("Информация"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            fetchShifts(for: newMonth)
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
    
    private func handleEditTap(_ shift: WorkShift) {
        selectedShift = shift
    }
    
    func confirmDelete(_ shift: WorkShift) {
        let alert = UIAlertController(title: "Удалить смену?",
                                    message: "Вы уверены, что хотите удалить смену?",
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            deleteShift(shift)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func deleteShift(_ shift: WorkShift) {
        let db = Firestore.firestore()
        db.collection("shifts").document(shift.id).delete { error in
            if let error = error {
                print("Ошибка удаления смены: \(error.localizedDescription)")
            } else {
                fetchShifts(for: selectedMonth)
            }
        }
    }
    
    private func fetchShifts(for date: Date) {
        isLoading = true
        let db = Firestore.firestore()
        
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
        let monthEnd = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        
        db.collection("shifts")
            .whereField("employeeName", isEqualTo: employeeName)
            .whereField("date", isGreaterThanOrEqualTo: formatDateKey(date: monthStart))
            .whereField("date", isLessThanOrEqualTo: formatDateKey(date: monthEnd))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Ошибка загрузки смен: \(error.localizedDescription)")
                } else {
                    var newShifts: [String: [WorkShift]] = [:]
                    
                    snapshot?.documents.forEach { document in
                        let data = document.data()
                        if let date = data["date"] as? String,
                           let startTime = data["startTime"] as? Timestamp,
                           let endTime = data["endTime"] as? Timestamp {
                            
                            let shift = WorkShift(
                                id: document.documentID,
                                employeeName: employeeName,
                                specialty: data["specialty"] as? String ?? "Не указано",
                                startTime: startTime,
                                endTime: endTime,
                                breakTime: data["breakTime"] as? Int ?? 0,
                                breakStartTime: data["breakStartTime"] as? Timestamp,
                                breakEndTime: data["breakEndTime"] as? Timestamp,
                                zone: data["zone"] as? String ?? "Неизвестно",
                                date: date,
                                status: data["status"] as? String ?? "assigned",
                                employeeId: data["employeeId"] as? String
                            )
                            
                            newShifts[date, default: []].append(shift)
                        }
                    }
                    
                    shifts = newShifts
                }
                isLoading = false
            }
    }
    
    private func fetchPendingExchanges() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("shiftExchangeOffers")
            .whereField("employeeId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Ошибка при загрузке обменов: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                self.pendingExchanges = documents.compactMap { $0.data()["shiftId"] as? String }
            }
    }
}


