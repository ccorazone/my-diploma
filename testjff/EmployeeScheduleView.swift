import SwiftUI
import Firebase
import FirebaseAuth

struct EmployeeScheduleView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MyScheduleView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Мое расписание")
                }
                .tag(0)
            
            AllShiftsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Все смены")
                }
                .tag(1)
            
            OpenShiftsView()
                .tabItem {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Обмен сменами")
                }
                .tag(2)
        }
    }
}

// Переименовываем старое представление в MyScheduleView
struct MyScheduleView: View {
    @State private var shifts: [String: [WorkShift]] = [:]
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var isLoading = true
    @State private var showChatList = false
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Кастомный заголовок
                    HStack {
                        Text("Расписание")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: { showChatList.toggle() }) {
                            Image(systemName: "message.fill")
                            //Image(systemName: "bubble.left.and.bubble.right.fill")
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
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(getShiftsForDate(selectedDate)) { shift in
                                ShiftCard(shift: shift)
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            fetchShifts()
        }
        .sheet(isPresented: $showChatList) {
            ChatListView()
        }
    }
    
    // Вспомогательные функции остаются теми же
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            fetchShifts()
        }
    }
    
    func getDaysInMonth() -> [Date] {
        let calendar = Calendar.current
        
        // Получаем первый день месяца
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        
        // Получаем первый день первой недели месяца (может быть из предыдущего месяца)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offsetDays = (firstWeekday + 5) % 7 // Корректировка для начала недели с понедельника
        let startDate = calendar.date(byAdding: .day, value: -offsetDays, to: firstDayOfMonth)!
        
        var dates: [Date] = []
        var currentDate = startDate
        
        // Генерируем даты для 6 недель
        for _ in 0..<42 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    func getShiftsForDate(_ date: Date) -> [WorkShift] {
        return shifts[formatDateKey(date: date)] ?? []
    }
    
    func formatMonthYear(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).capitalized
    }
    
    func formatFullDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    func formatDateKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func isSameMonth(date1: Date, date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
    }
    
    private func fetchShifts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            return
        }
        
        let db = Firestore.firestore()
        
        // Сначала получаем данные пользователя
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка получения данных пользователя: \(error.localizedDescription)")
                return
            }
            
            guard let userData = document?.data(),
                  let companyId = userData["companyId"] as? String,
                  let userName = userData["name"] as? String else {
                print("❌ Ошибка: не найдены данные пользователя")
                return
            }
            
            let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedMonth))!
            let monthEnd = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            
            print("🔍 Загрузка смен для пользователя: \(userId)")
            print("👤 Имя пользователя: \(userName)")
            print("🏢 CompanyId: \(companyId)")
            print("📅 Период: с \(monthStart) по \(monthEnd)")
            
            // Создаем два запроса: по employeeId и по employeeName
            let queryById = db.collection("shifts")
                .whereField("employeeId", isEqualTo: userId)
                .whereField("companyId", isEqualTo: companyId)
                .whereField("date", isGreaterThanOrEqualTo: formatDateKey(date: monthStart))
                .whereField("date", isLessThanOrEqualTo: formatDateKey(date: monthEnd))
            
            let queryByName = db.collection("shifts")
                .whereField("employeeName", isEqualTo: userName)
                .whereField("companyId", isEqualTo: companyId)
                .whereField("date", isGreaterThanOrEqualTo: formatDateKey(date: monthStart))
                .whereField("date", isLessThanOrEqualTo: formatDateKey(date: monthEnd))
            
            // Выполняем оба запроса
            queryById.getDocuments { snapshotById, errorById in
                queryByName.getDocuments { snapshotByName, errorByName in
                    var loadedShifts: [String: [WorkShift]] = [:]
                    
                    // Обрабатываем результаты обоих запросов
                    for snapshot in [snapshotById, snapshotByName] {
                        for document in snapshot?.documents ?? [] {
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
                                employeeId: data["employeeId"] as? String ?? userId
                            )
                            
                            // Проверяем, не добавили ли мы уже эту смену
                            if !loadedShifts[date, default: []].contains(where: { $0.id == shift.id }) {
                                loadedShifts[date, default: []].append(shift)
                            }
                        }
                    }
                    
                    self.shifts = loadedShifts
                    print("✅ Загружено смен по дням: \(self.shifts)")
                }
            }
        }
    }
}

//// Компонент ячейки дня
//struct DayCell: View {
//    let date: Date
//    @Binding var selectedDate: Date?
//    let shifts: [WorkShift]
//    let isCurrentMonth: Bool
//
//    private var isSelected: Bool {
//        guard let selectedDate = selectedDate else { return false }
//        return Calendar.current.isDate(date, inSameDayAs: selectedDate)
//    }
//
//    var body: some View {
//        VStack(spacing: 4) {
//            Text("\(Calendar.current.component(.day, from: date))")
//                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
//                .foregroundColor(isCurrentMonth ? (isSelected ? .white : .primary) : .gray)
//                .frame(width: 30, height: 30)
//                .background(isSelected ? Color.blue : Color.clear)
//                .clipShape(Circle())
//
//            if !shifts.isEmpty {
//                Circle()
//                    .fill(Color.green)
//                    .frame(width: 6, height: 6)
//            }
//        }
//        .frame(height: 45)
//        .background(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//        )
//    }
//}

// Удаляем дублирующий ShiftCard, так как теперь он находится в отдельном файле

