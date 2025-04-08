import SwiftUI
import Firebase
import FirebaseAuth

struct AddShiftView: View {
    @State private var selectedEmployees: Set<StaffMember> = []
    @State private var searchText = ""
    @State private var employees: [StaffMember] = []
    @State private var selectedZone: String = "Кухня"
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var breakStartTime: Date
    @State private var breakEndTime: Date
    @State private var isBreakEnabled = false
    @State private var showingEmployeeSearch = false
    @State private var isLoadingEmployees = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var employeesWithConflicts: [String] = []

    @Environment(\.presentationMode) var presentationMode
    var selectedDate: Date
    var onShiftAdded: () -> Void

    let zones = ["Кухня", "Зал ресторана", "Отель", "Кофейня", "Магазин"]

    init(selectedDate: Date, onShiftAdded: @escaping () -> Void) {
        self.selectedDate = selectedDate
        self.onShiftAdded = onShiftAdded
        
        // Устанавливаем время начала смены на 9:00
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = 9
        components.minute = 0
        let defaultStartTime = calendar.date(from: components) ?? selectedDate
        _startTime = State(initialValue: defaultStartTime)
        
        // Устанавливаем время конца смены на 17:00
        components.hour = 17
        let defaultEndTime = calendar.date(from: components) ?? selectedDate
        _endTime = State(initialValue: defaultEndTime)
        
        // Устанавливаем время начала перерыва на 13:00
        components.hour = 13
        let defaultBreakStartTime = calendar.date(from: components) ?? selectedDate
        _breakStartTime = State(initialValue: defaultBreakStartTime)
        
        // Устанавливаем время конца перерыва на 14:00
        components.hour = 14
        let defaultBreakEndTime = calendar.date(from: components) ?? selectedDate
        _breakEndTime = State(initialValue: defaultBreakEndTime)
    }

    var filteredEmployees: [StaffMember] {
        if searchText.isEmpty {
            return employees.sorted { $0.name < $1.name }
        }
        return employees.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.specialty.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    var shiftDuration: String {
        let workMinutes = Calendar.current.dateComponents([.minute], from: startTime, to: endTime).minute ?? 0
        let breakMinutes = isBreakEnabled ? (Calendar.current.dateComponents([.minute], from: breakStartTime, to: breakEndTime).minute ?? 0) : 0
        let totalMinutes = max(0, workMinutes - breakMinutes)
        return "\(totalMinutes / 60)ч \(totalMinutes % 60)м"
    }

    private func checkShiftConflicts(for employee: StaffMember, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let selectedDateString = formatter.string(from: selectedDate)
        
        db.collection("shifts")
            .whereField("employeeId", isEqualTo: employee.id)
            .whereField("date", isEqualTo: selectedDateString)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Ошибка проверки конфликтов: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(false)
                    return
                }
                
                for document in documents {
                    let data = document.data()
                    guard let existingStartTime = (data["startTime"] as? Timestamp)?.dateValue(),
                          let existingEndTime = (data["endTime"] as? Timestamp)?.dateValue() else {
                        continue
                    }
                    
                    // Проверяем пересечение времени
                    if (startTime <= existingEndTime && endTime >= existingStartTime) {
                        completion(true)
                        return
                    }
                }
                
                completion(false)
            }
    }

    private func validateAndSaveShift() {
        guard !selectedEmployees.isEmpty else { return }
        
        let group = DispatchGroup()
        employeesWithConflicts = []
        
        for employee in selectedEmployees {
            group.enter()
            checkShiftConflicts(for: employee) { hasConflict in
                if hasConflict {
                    employeesWithConflicts.append(employee.name)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !employeesWithConflicts.isEmpty {
                alertMessage = "Обнаружены конфликты смен для следующих сотрудников:\n\n" +
                             employeesWithConflicts.joined(separator: "\n") +
                             "\n\nПожалуйста, измените время смены или выберите других сотрудников."
                showAlert = true
            } else {
                saveShift()
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Сотрудники")) {
                    Button(action: {
                        if employees.isEmpty {
                            fetchEmployees()
                        }
                        showingEmployeeSearch = true
                    }) {
                        HStack {
                            if isLoadingEmployees {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 5)
                            }
                            Text(selectedEmployees.isEmpty ? "Выберите сотрудников" : "\(selectedEmployees.count) выбрано")
                                .foregroundColor(selectedEmployees.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }

                if !selectedEmployees.isEmpty {
                    Section(header: Text("Выбранные сотрудники")) {
                        ForEach(Array(selectedEmployees), id: \.id) { employee in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(employee.name)
                                    Text(employee.specialty)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button(action: {
                                    selectedEmployees.remove(employee)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Зона работы")) {
                    Picker("Выберите зону", selection: $selectedZone) {
                        ForEach(zones, id: \.self) { zone in
                            Text(zone).tag(zone)
                        }
                    }
                }

                Section(header: Text("Время смены")) {
                    DatePicker("Начало", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Конец", selection: $endTime, displayedComponents: .hourAndMinute)
                    Text("Рабочее время: \(shiftDuration)")
                        .foregroundColor(.blue)
                }

                Section(header: Text("Перерыв")) {
                    Toggle("Добавить перерыв", isOn: $isBreakEnabled)

                    if isBreakEnabled {
                        DatePicker("Начало перерыва", selection: $breakStartTime, displayedComponents: .hourAndMinute)
                        DatePicker("Конец перерыва", selection: $breakEndTime, displayedComponents: .hourAndMinute)
                        if let breakDuration = Calendar.current.dateComponents([.minute], from: breakStartTime, to: breakEndTime).minute {
                            Text("Длительность перерыва: \(breakDuration) мин")
                                .foregroundColor(.orange)
                        }
                    }
                }

                Button(action: validateAndSaveShift) {
                    Text("Добавить смену")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedEmployees.isEmpty)
                .padding()
            }
            .navigationTitle("Добавить смену")
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingEmployeeSearch) {
                EmployeeSearchView(
                    searchText: $searchText,
                    selectedEmployees: $selectedEmployees,
                    employees: employees
                )
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Внимание"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                if employees.isEmpty {
                    fetchEmployees()
                }
            }
        }
    }

    func fetchEmployees() {
        guard !isLoadingEmployees else { return }
        isLoadingEmployees = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            isLoadingEmployees = false
            return
        }

        let db = Firestore.firestore()
        
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка получения companyId: \(error.localizedDescription)")
                isLoadingEmployees = false
                return
            }

            if let document = document, document.exists,
               let companyId = document.data()?["companyId"] as? String {
                
                print("✅ Найден companyId: \(companyId)")

                db.collection("users")
                    .whereField("companyId", isEqualTo: companyId)
                    .whereField("role", isEqualTo: "employee")
                    .getDocuments { snapshot, error in
                        defer { isLoadingEmployees = false }
                        
                        if let error = error {
                            print("❌ Ошибка загрузки сотрудников: \(error.localizedDescription)")
                        } else {
                            self.employees = snapshot?.documents.compactMap { doc in
                                let data = doc.data()
                                return StaffMember(
                                    id: doc.documentID,
                                    name: data["name"] as? String ?? "Неизвестно",
                                    email: data["email"] as? String ?? "",
                                    specialty: data["specialty"] as? String ?? "Не указано"
                                )
                            } ?? []
                            print("✅ Загружено сотрудников: \(self.employees.count)")
                        }
                    }
            } else {
                print("❌ Не найден companyId у пользователя \(userId)")
                isLoadingEmployees = false
            }
        }
    }

    func saveShift() {
        guard !selectedEmployees.isEmpty else { return }
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
                
                print("✅ Найден companyId: \(companyId)")

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let selectedDateString = formatter.string(from: selectedDate)

                let breakMinutes = isBreakEnabled ? Calendar.current.dateComponents([.minute], from: breakStartTime, to: breakEndTime).minute ?? 0 : 0

                let group = DispatchGroup()
                
                for employee in selectedEmployees {
                    group.enter()
                    
                    let shiftData: [String: Any] = [
                        "companyId": companyId,
                        "employeeName": employee.name,
                        "employeeId": employee.id,
                        "specialty": employee.specialty,
                        "date": selectedDateString,
                        "startTime": Timestamp(date: startTime),
                        "endTime": Timestamp(date: endTime),
                        "breakTime": breakMinutes,
                        "breakStartTime": isBreakEnabled ? Timestamp(date: breakStartTime) : nil,
                        "breakEndTime": isBreakEnabled ? Timestamp(date: breakEndTime) : nil,
                        "zone": selectedZone
                    ]

                    db.collection("shifts").addDocument(data: shiftData) { error in
                        if let error = error {
                            print("❌ Ошибка добавления смены для \(employee.name): \(error.localizedDescription)")
                        } else {
                            print("✅ Смена успешно добавлена для \(employee.name)")
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    onShiftAdded()
                    presentationMode.wrappedValue.dismiss()
                }
            } else {
                print("❌ Не найден companyId у пользователя \(userId)")
            }
        }
    }
}

struct EmployeeSearchView: View {
    @Binding var searchText: String
    @Binding var selectedEmployees: Set<StaffMember>
    let employees: [StaffMember]
    @Environment(\.presentationMode) var presentationMode
    
    var filteredAndGroupedEmployees: [String: [StaffMember]] {
        let employeesToShow = searchText.isEmpty ?
            employees :
            employees.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.specialty.localizedCaseInsensitiveContains(searchText)
            }
        
        let sortedEmployees = employeesToShow.sorted { $0.name < $1.name }
        return Dictionary(grouping: sortedEmployees) { String($0.name.prefix(1)).uppercased() }
    }
    
    var sortedKeys: [String] {
        filteredAndGroupedEmployees.keys.sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                    .padding()
                
                if employees.isEmpty {
                    VStack {
                        Text("Нет доступных сотрудников")
                            .foregroundColor(.gray)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sortedKeys.isEmpty {
                    VStack {
                        Text("Сотрудники не найдены")
                            .foregroundColor(.gray)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header: Text(key)) {
                                ForEach(filteredAndGroupedEmployees[key] ?? [], id: \.id) { employee in
                                    EmployeeRow(
                                        employee: employee,
                                        isSelected: selectedEmployees.contains(employee)
                                    ) {
                                        if selectedEmployees.contains(employee) {
                                            selectedEmployees.remove(employee)
                                        } else {
                                            selectedEmployees.insert(employee)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                }
            }
            .navigationTitle("Выбор сотрудников")
            .navigationBarItems(
                trailing: Button("Готово") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Поиск по имени или специальности", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct EmployeeRow: View {
    let employee: StaffMember
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(employee.name)
                        .foregroundColor(.primary)
                    Text(employee.specialty)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// 🔹 Модель сотрудника
struct StaffMember: Identifiable, Hashable {
    var id: String
    var name: String
    var email: String
    var specialty: String

    static func == (lhs: StaffMember, rhs: StaffMember) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
