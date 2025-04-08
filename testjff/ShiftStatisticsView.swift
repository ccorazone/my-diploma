import SwiftUI
import Firebase
import FirebaseAuth

struct ShiftStatisticsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMonth = Date()
    @State private var monthlyStats: [String: Double] = [:] // Статистика по зонам
    @State private var employeeStats: [String: [WeeklyStats]] = [:] // Статистика по сотрудникам
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var allEmployees: [StaffMember] = [] // Все сотрудники
    @State private var totalMonthlyHours: [String: Double] = [:] // Общие часы за месяц по сотрудникам
    @State private var totalCompanyHours: Double = 0 // Общие часы компании за месяц
    
    // Структура для хранения статистики по неделям
    struct WeeklyStats: Identifiable {
        let id = UUID()
        let weekNumber: Int
        let hours: Double
        let startDate: Date
        let endDate: Date
        let hasShifts: Bool // Флаг наличия смен в эту неделю
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Селектор месяца
                    HStack {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                        }
                        
                        Text(monthFormatter.string(from: selectedMonth))
                            .font(.headline)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        // Общая статистика компании
                        VStack(spacing: 10) {
                            Text("Общая статистика")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Всего часов за месяц:")
                                        .font(.headline)
                                    Text("\(String(format: "%.1f", totalCompanyHours)) ч")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                        }
                        .padding(.horizontal)
                        
                        if allEmployees.isEmpty {
                            Text("Нет доступных сотрудников")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            // Статистика по сотрудникам
                            ForEach(allEmployees, id: \.id) { employee in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(employee.name)
                                                .font(.headline)
                                            Text(employee.specialty)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("Всего часов: \(String(format: "%.1f", totalMonthlyHours[employee.id] ?? 0))")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal)
                                    
                                    // Недельная статистика
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            if let stats = employeeStats[employee.id] {
                                                ForEach(stats) { weekStats in
                                                    VStack {
                                                        Text("Неделя \(weekStats.weekNumber)")
                                                            .font(.caption)
                                                        Text("\(String(format: "%.1f", weekStats.hours)) ч")
                                                            .font(.body)
                                                            .foregroundColor(weekStats.hasShifts ? .primary : .gray)
                                                        Text("\(formatDate(weekStats.startDate)) - \(formatDate(weekStats.endDate))")
                                                            .font(.caption2)
                                                            .foregroundColor(.gray)
                                                    }
                                                    .padding()
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(Color(.systemBackground))
                                                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                                                    )
                                                }
                                            } else {
                                                Text("Нет данных")
                                                    .foregroundColor(.gray)
                                                    .padding()
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(15)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Статистика")
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                loadEmployees()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Уведомление"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            loadStatistics()
        }
    }
    
    private func loadEmployees() {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ Ошибка: Пользователь не авторизован")
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).getDocument { (document, error) in
            if let error = error {
                print("❌ Ошибка получения данных пользователя: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            if let document = document, document.exists,
               let companyId = document.data()?["companyId"] as? String {
                
                print("✅ Найден companyId: \(companyId)")
                
                // Изменяем запрос для поиска сотрудников в коллекции users
                db.collection("users")
                    .whereField("companyId", isEqualTo: companyId)
                    .whereField("role", isEqualTo: "employee")
                    .getDocuments { (querySnapshot, error) in
                        if let error = error {
                            print("❌ Ошибка загрузки сотрудников: \(error.localizedDescription)")
                            isLoading = false
                            return
                        }
                        
                        self.allEmployees = querySnapshot?.documents.compactMap { document -> StaffMember? in
                            let data = document.data()
                            return StaffMember(
                                id: document.documentID,
                                name: data["name"] as? String ?? "",
                                email: data["email"] as? String ?? "",
                                specialty: data["specialty"] as? String ?? ""
                            )
                        } ?? []
                        
                        print("✅ Загружено сотрудников: \(self.allEmployees.count)")
                        
                        if self.allEmployees.isEmpty {
                            print("⚠️ Список сотрудников пуст!")
                            isLoading = false
                        } else {
                            // После загрузки сотрудников загружаем статистику
                            loadStatistics()
                        }
                    }
            } else {
                print("❌ Не найден companyId у пользователя \(currentUser.uid)")
                isLoading = false
            }
        }
    }
    
    private func loadStatistics() {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ Ошибка: Пользователь не авторизован")
            isLoading = false
            return
        }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        print("📅 Загрузка статистики для периода: \(startOfMonth) - \(endOfMonth)")
        
        // Создаем пустые недели для всего месяца
        var allWeeks: [Int: WeeklyStats] = [:]
        var currentDate = startOfMonth
        
        while currentDate <= endOfMonth {
            let weekNumber = calendar.component(.weekOfYear, from: currentDate)
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            allWeeks[weekNumber] = WeeklyStats(
                weekNumber: weekNumber,
                hours: 0,
                startDate: weekStart,
                endDate: weekEnd,
                hasShifts: false
            )
            
            currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!
        }
        
        // Инициализируем пустую статистику для всех сотрудников
        var newEmployeeStats: [String: [WeeklyStats]] = [:]
        totalMonthlyHours = [:]
        totalCompanyHours = 0 // Сбрасываем общее количество часов
        
        for employee in allEmployees {
            newEmployeeStats[employee.id] = Array(allWeeks.values).sorted { $0.weekNumber < $1.weekNumber }
            totalMonthlyHours[employee.id] = 0
        }
        
        // Загружаем реальные данные о сменах
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).getDocument { (document, error) in
            if let error = error {
                print("❌ Ошибка получения данных пользователя: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            if let document = document, document.exists,
               let companyId = document.data()?["companyId"] as? String {
                
                print("✅ Найден companyId для загрузки смен: \(companyId)")
                
                db.collection("shifts")
                    .whereField("companyId", isEqualTo: companyId)
                    .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfMonth))
                    .whereField("endTime", isLessThanOrEqualTo: Timestamp(date: endOfMonth))
                    .getDocuments { (querySnapshot, error) in
                        if let error = error {
                            print("❌ Ошибка загрузки смен: \(error.localizedDescription)")
                            isLoading = false
                            return
                        }
                        
                        print("📊 Найдено смен: \(querySnapshot?.documents.count ?? 0)")
                        
                        for document in querySnapshot?.documents ?? [] {
                            let data = document.data()
                            if let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
                               let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                               let employeeId = data["employeeId"] as? String {
                                
                                let weekNumber = calendar.component(.weekOfYear, from: startTime)
                                let hours = endTime.timeIntervalSince(startTime) / 3600
                                
                                // Обновляем общее количество часов за месяц для сотрудника
                                totalMonthlyHours[employeeId, default: 0] += hours
                                
                                // Обновляем общее количество часов компании
                                totalCompanyHours += hours
                                
                                // Обновляем статистику по неделям
                                if var employeeWeeklyStats = newEmployeeStats[employeeId] {
                                    if let weekIndex = employeeWeeklyStats.firstIndex(where: { $0.weekNumber == weekNumber }) {
                                        let currentStats = employeeWeeklyStats[weekIndex]
                                        employeeWeeklyStats[weekIndex] = WeeklyStats(
                                            weekNumber: weekNumber,
                                            hours: currentStats.hours + hours,
                                            startDate: currentStats.startDate,
                                            endDate: currentStats.endDate,
                                            hasShifts: true
                                        )
                                        newEmployeeStats[employeeId] = employeeWeeklyStats
                                    }
                                }
                            }
                        }
                        
                        // Обновляем состояние
                        self.employeeStats = newEmployeeStats
                        print("✅ Статистика успешно загружена")
                        print("💼 Общее количество часов компании: \(self.totalCompanyHours)")
                        isLoading = false
                    }
            } else {
                print("❌ Не найден companyId у пользователя \(currentUser.uid)")
                isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }
}
