import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth


struct ExchangeRequest: Identifiable {
    let id: String
    let shiftId: String
    let employeeId: String
    let message: String
    let timestamp: Timestamp
    let status: String
    var shift: WorkShift?
    var employeeName: String = ""
    var acceptedBy: [AcceptedEmployee] = [] // Сотрудники, принявшие запрос
}

struct AcceptedEmployee: Identifiable {
    let id: String
    let name: String
    let timestamp: Timestamp
    let message: String
}

struct ExchangeRequestsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var requests: [ExchangeRequest] = []
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private func formatShiftDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .none
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if requests.isEmpty {
                    VStack {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        Text("Нет запросов на обмен")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(requests) { request in
                            if let shift = request.shift {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Статус запроса
                                    HStack {
                                        Circle()
                                            .fill(request.acceptedBy.isEmpty ? Color.orange : Color.green)
                                            .frame(width: 10, height: 10)
                                        Text(request.acceptedBy.isEmpty ? "Ожидает принятия" : "Есть желающие принять")
                                            .font(.caption)
                                            .foregroundColor(request.acceptedBy.isEmpty ? .orange : .green)
                                        Spacer()
                                        Text(formatDate(request.timestamp.dateValue()))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Divider()
                                    
                                    // Информация о смене
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Детали смены:")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        HStack {
                                            Image(systemName: "person.fill")
                                            Text(shift.employeeName)
                                        }
                                        .foregroundColor(.primary)
                                        
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                            Text(shift.zone)
                                        }
                                        .foregroundColor(.blue)
                                        
                                        HStack {
                                            Image(systemName: "calendar")
                                            Text("\(formatShiftDate(shift.date))")
                                            Text("\(formatTime(shift.startTime.dateValue())) - \(formatTime(shift.endTime.dateValue()))")
                                        }
                                        .foregroundColor(.green)
                                    }
                                    .padding(.vertical, 4)
                                    
                                    if !request.message.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Сообщение:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Text(request.message)
                                                .font(.subheadline)
                                                .padding(8)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                        }
                                    }
                                    
                                    // Список принявших сотрудников
                                    if !request.acceptedBy.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Желающие принять смену:")
                                                .font(.headline)
                                                .padding(.top, 8)
                                            
                                            ForEach(request.acceptedBy) { employee in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Image(systemName: "person.circle.fill")
                                                            .foregroundColor(.blue)
                                                        Text(employee.name)
                                                            .font(.subheadline)
                                                    }
                                                    
                                                    if !employee.message.isEmpty {
                                                        Text(employee.message)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    Text("Принял запрос: \(formatDate(employee.timestamp.dateValue()))")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                    
                                                    Button(action: {
                                                        approveRequest(request, newEmployeeId: employee.id, newEmployeeName: employee.name)
                                                    }) {
                                                        Text("Выбрать этого сотрудника")
                                                            .foregroundColor(.white)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 8)
                                                            .background(Color.blue)
                                                            .cornerRadius(8)
                                                    }
                                                }
                                                .padding(8)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                    
                                    // Кнопка действия
                                    if request.acceptedBy.isEmpty {
                                        Button(action: {
                                            rejectRequest(request)
                                        }) {
                                            HStack {
                                                Image(systemName: "xmark.circle.fill")
                                                Text("Отклонить запрос")
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.red)
                                            .cornerRadius(8)
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Запросы на обмен")
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                print("📱 Загрузка представления запросов на обмен")
                fetchRequests()
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
    
    private func fetchRequests() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            return
        }
        
        isLoading = true
        let db = Firestore.firestore()
        print("🔍 Начинаем загрузку запросов на обмен")
        
        // Получаем companyId текущего пользователя
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка получения данных пользователя: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            guard let document = document,
                  let companyId = document.data()?["companyId"] as? String else {
                print("❌ Не найден companyId пользователя")
                self.isLoading = false
                return
            }
            
            print("✅ Найден companyId: \(companyId)")
            
            // Получаем все запросы на обмен
            db.collection("shiftExchangeOffers")
                .whereField("status", isEqualTo: "pending")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ Ошибка загрузки запросов: \(error.localizedDescription)")
                        self.isLoading = false
                        return
                    }
                    
                    let documents = snapshot?.documents ?? []
                    print("📝 Найдено запросов: \(documents.count)")
                    
                    if documents.isEmpty {
                        print("📭 Нет доступных запросов")
                        DispatchQueue.main.async {
                            self.requests = []
                            self.isLoading = false
                        }
                        return
                    }
                    
                    let dispatchGroup = DispatchGroup()
                    var newRequests: [ExchangeRequest] = []
                    
                    for document in documents {
                        dispatchGroup.enter()
                        let data = document.data()
                        let requestId = document.documentID
                        print("🔄 Обработка запроса: \(requestId)")
                        
                        guard let shiftId = data["shiftId"] as? String,
                              let employeeId = data["employeeId"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            print("❌ Пропущен запрос из-за отсутствия обязательных полей")
                            dispatchGroup.leave()
                            continue
                        }
                        
                        // Создаем запрос
                        var request = ExchangeRequest(
                            id: requestId,
                            shiftId: shiftId,
                            employeeId: employeeId,
                            message: data["message"] as? String ?? "",
                            timestamp: timestamp,
                            status: data["status"] as? String ?? "pending"
                        )
                        
                        // Получаем информацию о смене
                        db.collection("shifts").document(shiftId).getDocument { shiftDoc, error in
                            if let error = error {
                                print("❌ Ошибка загрузки смены \(shiftId): \(error.localizedDescription)")
                                dispatchGroup.leave()
                                return
                            }
                            
                            guard let shiftData = shiftDoc?.data(),
                                  let startTime = shiftData["startTime"] as? Timestamp,
                                  let endTime = shiftData["endTime"] as? Timestamp,
                                  let date = shiftData["date"] as? String,
                                  let shiftCompanyId = shiftData["companyId"] as? String,
                                  shiftCompanyId == companyId else {
                                print("❌ Пропущена смена из-за несоответствия данных")
                                dispatchGroup.leave()
                                return
                            }
                            
                            request.shift = WorkShift(
                                id: shiftDoc!.documentID,
                                employeeName: shiftData["employeeName"] as? String ?? "",
                                specialty: shiftData["specialty"] as? String ?? "",
                                startTime: startTime,
                                endTime: endTime,
                                breakTime: shiftData["breakTime"] as? Int ?? 0,
                                zone: shiftData["zone"] as? String ?? "",
                                date: date,
                                employeeId: shiftData["employeeId"] as? String
                            )
                            
                            // Получаем информацию о принявших запрос
                            db.collection("shiftExchangeAccepts")
                                .whereField("shiftId", isEqualTo: shiftId)
                                .whereField("status", isEqualTo: "pending")
                                .getDocuments { acceptsSnapshot, error in
                                    if let error = error {
                                        print("❌ Ошибка загрузки принявших запрос: \(error.localizedDescription)")
                                        dispatchGroup.leave()
                                        return
                                    }
                                    
                                    let acceptDocs = acceptsSnapshot?.documents ?? []
                                    print("👥 Найдено принявших запрос \(shiftId): \(acceptDocs.count)")
                                    
                                    var acceptedEmployees: [AcceptedEmployee] = []
                                    let acceptGroup = DispatchGroup()
                                    
                                    if acceptDocs.isEmpty {
                                        print("📝 Нет принявших для запроса \(requestId)")
                                        request.acceptedBy = []
                                        newRequests.append(request)
                                        dispatchGroup.leave()
                                        return
                                    }
                                    
                                    for acceptDoc in acceptDocs {
                                        acceptGroup.enter()
                                        let acceptData = acceptDoc.data()
                                        
                                        if let acceptEmployeeId = acceptData["employeeId"] as? String,
                                           let acceptTimestamp = acceptData["timestamp"] as? Timestamp,
                                           acceptEmployeeId != employeeId {
                                            
                                            db.collection("users").document(acceptEmployeeId).getDocument { userDoc, error in
                                                defer { acceptGroup.leave() }
                                                
                                                if let userData = userDoc?.data(),
                                                   let userName = userData["name"] as? String {
                                                    let acceptedEmployee = AcceptedEmployee(
                                                        id: acceptEmployeeId,
                                                        name: userName,
                                                        timestamp: acceptTimestamp,
                                                        message: acceptData["message"] as? String ?? ""
                                                    )
                                                    acceptedEmployees.append(acceptedEmployee)
                                                    print("✅ Добавлен принявший сотрудник: \(userName) для запроса \(requestId)")
                                                }
                                            }
                                        } else {
                                            acceptGroup.leave()
                                        }
                                    }
                                    
                                    acceptGroup.notify(queue: .main) {
                                        request.acceptedBy = acceptedEmployees
                                        newRequests.append(request)
                                        print("✅ Добавлен запрос: \(requestId) с \(acceptedEmployees.count) принявшими")
                                        dispatchGroup.leave()
                                    }
                                }
                        }
                    }
                    
                    dispatchGroup.notify(queue: .main) {
                        self.requests = newRequests.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                        print("✅ Загружено и отсортировано запросов: \(self.requests.count)")
                        self.isLoading = false
                    }
                }
        }
    }
    
    private func approveRequest(_ request: ExchangeRequest, newEmployeeId: String, newEmployeeName: String) {
        guard let shift = request.shift else { return }
        
        let db = Firestore.firestore()
        print("🔄 Начало процесса одобрения запроса")
        
        // Обновляем статус запроса
        db.collection("shiftExchangeOffers").document(request.id).updateData([
            "status": "approved",
            "approvedEmployeeId": newEmployeeId
        ]) { error in
            if let error = error {
                print("❌ Ошибка при обновлении запроса: \(error.localizedDescription)")
                alertMessage = "Ошибка при обновлении запроса: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            print("✅ Статус запроса обновлен")
            
            // Обновляем смену с новым сотрудником
            db.collection("shifts").document(shift.id).updateData([
                "employeeId": newEmployeeId,
                "employeeName": newEmployeeName
            ]) { error in
                if let error = error {
                    print("❌ Ошибка при обновлении смены: \(error.localizedDescription)")
                    alertMessage = "Ошибка при обновлении смены: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                print("✅ Смена успешно переназначена сотруднику \(newEmployeeName)")
                alertMessage = "Запрос на обмен одобрен"
                showAlert = true
                fetchRequests()
            }
        }
    }
    
    private func rejectRequest(_ request: ExchangeRequest) {
        let db = Firestore.firestore()
        print("🔄 Начало процесса отклонения запроса")
        
        db.collection("shiftExchangeOffers").document(request.id).updateData([
            "status": "rejected"
        ]) { error in
            if let error = error {
                print("❌ Ошибка при отклонении запроса: \(error.localizedDescription)")
                alertMessage = "Ошибка при отклонении запроса: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            print("✅ Запрос успешно отклонен")
            alertMessage = "Запрос на обмен отклонен"
            showAlert = true
            fetchRequests()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
} 
