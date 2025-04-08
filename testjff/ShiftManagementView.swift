import SwiftUI
import Firebase
import FirebaseAuth

struct ShiftManagementView: View {
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var shifts: [String: [WorkShift]] = [:]
    @State private var isLoading = true
    @State private var showAddShiftSheet = false
    @State private var showEditShiftSheet = false
    @State private var selectedShift: WorkShift?
    @State private var showStatisticsSheet = false
    @State private var showExchangeRequestsSheet = false
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let zones = ["Кухня", "Зал ресторана", "Отель", "Кофейня", "Магазин"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        // Кастомный заголовок
                        HStack {
                            Text("Смены")
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            
                            Button(action: {
                                showExchangeRequestsSheet.toggle()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .padding(.trailing, 8)
                            
                            Button(action: {
                                showStatisticsSheet.toggle()
                            }) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .padding(.trailing, 8)
                            
                            Button(action: {
                                showAddShiftSheet.toggle()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
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
                                
                                ForEach(zones, id: \.self) { zone in
                                    let shiftsInZone = getShiftsForDateAndZone(selectedDate, zone)
                                    if !shiftsInZone.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(zone)
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                
                                                Spacer()
                                                
                                                // Общее количество часов в зоне за день
                                                let totalHours = calculateTotalHours(shifts: shiftsInZone)
                                                Text("\(String(format: "%.1f", totalHours)) ч")
                                                    .font(.subheadline)
                                                    .foregroundColor(.blue)
                                            }
                                            .padding(.horizontal)
                                            
                                            ForEach(shiftsInZone) { shift in
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text(shift.employeeName)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                        .padding(.horizontal)
                                                    
                                                    NavigationLink(destination: EmployeeShiftsView(employeeName: shift.employeeName)) {
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
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddShiftSheet) {
                AddShiftView(selectedDate: selectedDate ?? Date()) {
                    fetchShifts()
                }
            }
            .sheet(isPresented: $showStatisticsSheet) {
                ShiftStatisticsView()
            }
            .sheet(isPresented: $showExchangeRequestsSheet) {
                ExchangeRequestsView()
            }
            .sheet(isPresented: $showEditShiftSheet) {
                if let shift = selectedShift {
                    EditShiftView(shift: shift) {
                        fetchShifts()
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
                fetchShifts()
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            fetchShifts()
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
    
    private func getShiftsForDateAndZone(_ date: Date, _ zone: String) -> [WorkShift] {
        let dateKey = formatDateKey(date: date)
        return shifts[dateKey]?.filter { $0.zone == zone }
            .sorted { $0.startTime.dateValue() < $1.startTime.dateValue() } ?? []
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
                fetchShifts()
            }
        }
    }
    
    private func fetchShifts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка получения companyId: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists,
               let companyId = document.data()?["companyId"] as? String {
                
                let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedMonth))!
                let monthEnd = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
                
                db.collection("shifts")
                    .whereField("companyId", isEqualTo: companyId)
                    .whereField("date", isGreaterThanOrEqualTo: formatDateKey(date: monthStart))
                    .whereField("date", isLessThanOrEqualTo: formatDateKey(date: monthEnd))
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("❌ Ошибка загрузки смен: \(error.localizedDescription)")
                        } else {
                            var newShifts: [String: [WorkShift]] = [:]
                            
                            snapshot?.documents.forEach { document in
                                let data = document.data()
                                if let date = data["date"] as? String,
                                   let startTime = data["startTime"] as? Timestamp,
                                   let endTime = data["endTime"] as? Timestamp {
                                    
                                    let shift = WorkShift(
                                        id: document.documentID,
                                        employeeName: data["employeeName"] as? String ?? "Неизвестно",
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
        }
    }
    
    private func handleEditTap(_ shift: WorkShift) {
        selectedShift = shift
        showEditShiftSheet = true
    }
    
    // Добавляем функцию для подсчета общего количества часов
    private func calculateTotalHours(shifts: [WorkShift]) -> Double {
        shifts.reduce(0.0) { total, shift in
            let duration = shift.endTime.dateValue().timeIntervalSince(shift.startTime.dateValue())
            let hours = duration / 3600.0
            // Вычитаем время перерыва, если оно есть
            if let breakTime = shift.breakTime {
                return total + hours - (Double(breakTime) / 60.0)
            }
            return total + hours
        }
    }
}

