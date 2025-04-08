import SwiftUI
import Firebase
import FirebaseStorage

struct EmployeeDetailView: View {
    let employee: AppUser
    @State private var isLoading = true
    @State private var shifts: [Shift] = []
    @State private var avatarImage: UIImage? = nil
    
    // Добавляем вычисляемое свойство для фильтрованных смен
    private var filteredShifts: [Shift] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        print("\n🕒 Текущее время (now): \(formatDateWithTime(now))")
        print("📅 Начало дня (today): \(formatDateWithTime(today))")
        
        let filtered = shifts.filter { shift in
            // Парсим дату из строки date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            guard let shiftDate = dateFormatter.date(from: shift.date) else {
                print("⚠️ Ошибка парсинга даты для смены \(shift.id)")
                return false
            }
            
            print("\n🔍 Проверка смены \(shift.id):")
            print("   📅 Дата смены из поля date: \(formatDateWithTime(shiftDate))")
            
            // Сравниваем только даты
            let shiftComponents = calendar.dateComponents([.year, .month, .day], from: shiftDate)
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
            
            print("   📊 Компоненты даты смены: год \(shiftComponents.year!), месяц \(shiftComponents.month!), день \(shiftComponents.day!)")
            print("   📊 Компоненты сегодня: год \(todayComponents.year!), месяц \(todayComponents.month!), день \(todayComponents.day!)")
            
            let shiftDateOnly = calendar.date(from: shiftComponents)!
            let todayDateOnly = calendar.date(from: todayComponents)!
            
            let isValid = shiftDateOnly >= todayDateOnly
            print("   ✅ Показывать: \(isValid)")
            return isValid
        }.sorted { shift1, shift2 in
            // Сортируем по дате, а затем по времени начала
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date1 = dateFormatter.date(from: shift1.date) ?? Date()
            let date2 = dateFormatter.date(from: shift2.date) ?? Date()
            if date1 == date2 {
                return shift1.startTime < shift2.startTime
            }
            return date1 < date2
        }
        
        print("\n📊 Отфильтровано смен для отображения: \(filtered.count)")
        if filtered.isEmpty {
            print("❌ Нет смен для отображения")
        } else {
            print("✅ Смены для отображения:")
            filtered.forEach { shift in
                print("   🕒 Смена \(shift.id): \(formatDateWithTime(shift.startTime)) - \(formatDateWithTime(shift.endTime))")
            }
        }
        return filtered
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Аватар и основная информация
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        if let avatar = avatarImage {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.blue)
                                .frame(width: 110, height: 110)
                        }
                        
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 120, height: 120)
                    }
                    
                    Text(employee.name.isEmpty ? "Без имени" : employee.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(employee.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical)
                
                // Информация о сотруднике
                GroupBox(label: Label("Информация о сотруднике", systemImage: "person.text.rectangle")) {
                    VStack(alignment: .leading, spacing: 15) {
                        ProfileInfoRow(icon: "briefcase", title: "Должность", value: employee.specialty)
                        ProfileInfoRow(icon: "person.badge.key", title: "Роль", value: employee.role.capitalized)
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal)
                
                // Текущие смены
                GroupBox(label: Label("Текущие смены", systemImage: "calendar")) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if filteredShifts.isEmpty {
                        Text("Нет активных смен")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(filteredShifts) { shift in
                                    ShiftCard(shift: convertToWorkShift(shift))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Профиль сотрудника")
        .onAppear {
            fetchEmployeeShifts()
            loadAvatarImage()
        }
    }
    
    private func fetchEmployeeShifts() {
        let db = Firestore.firestore()
        
        print("\n🔄 Начало загрузки смен")
        print("👤 ID сотрудника: \(employee.id)")
        
        let shiftsQuery = db.collection("shifts")
            .whereField("employeeId", isEqualTo: employee.id)
        
        shiftsQuery.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Ошибка загрузки смен: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            shifts = snapshot?.documents.compactMap { document in
                let data = document.data()
                
                guard let startTimestamp = data["startTime"] as? Timestamp,
                      let endTimestamp = data["endTime"] as? Timestamp,
                      let date = data["date"] as? String else {
                    print("⚠️ Пропущена смена \(document.documentID): отсутствуют обязательные поля")
                    return nil
                }
                
                let breakTime = data["breakTime"] as? Int
                print("🕒 Смена \(document.documentID):")
                print("   Перерыв: \(breakTime ?? 0) минут")
                
                let shift = Shift(
                    id: document.documentID,
                    employeeId: data["employeeId"] as? String ?? "",
                    startTime: startTimestamp.dateValue(),
                    endTime: endTimestamp.dateValue(),
                    status: data["status"] as? String ?? "active",
                    zone: data["zone"] as? String ?? "",
                    position: data["specialty"] as? String ?? "",
                    date: date,
                    breakTime: breakTime ?? 0
                )
                
                return shift
            } ?? []
            
            isLoading = false
        }
    }
    
    private func loadAvatarImage() {
        let storageRef = Storage.storage().reference().child("avatars/\(employee.id).jpg")
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("❌ Ошибка загрузки аватара: \(error.localizedDescription)")
                return
            }
            if let data = data {
                self.avatarImage = UIImage(data: data)
            }
        }
    }
    
    private func convertToWorkShift(_ shift: Shift) -> WorkShift {
        return WorkShift(
            id: shift.id,
            employeeName: employee.name,
            specialty: employee.specialty,
            startTime: Timestamp(date: shift.startTime),
            endTime: Timestamp(date: shift.endTime),
            breakTime: shift.breakTime,
            zone: shift.zone,
            date: shift.date,
            status: shift.status,
            employeeId: shift.employeeId
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // Добавляем функцию для форматирования даты со временем
    private func formatDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

struct Shift: Identifiable {
    let id: String
    let employeeId: String
    let startTime: Date
    let endTime: Date
    let status: String
    let zone: String
    let position: String
    let date: String
    let breakTime: Int
}
