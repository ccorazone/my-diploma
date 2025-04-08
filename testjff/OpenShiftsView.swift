import SwiftUI
import Firebase
import FirebaseAuth

struct OpenShiftsView: View {
    @State private var openShifts: [WorkShift] = []
    @State private var myShifts: [String: [WorkShift]] = [:] // Группировка по датам
    @State private var isLoading = true
    @State private var showingOfferSheet = false
    @State private var selectedShift: WorkShift?
    @State private var pendingRequests: Set<String> = []
    @State private var pendingExchanges: Set<String> = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentUserId: String = ""
    
    var sortedDates: [String] {
        myShifts.keys.sorted()
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Секция доступных смен
                    Section(header: Text("Доступные смены")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)) {
                        if openShifts.isEmpty {
                            Text("Нет доступных смен")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(openShifts) { shift in
                                VStack(spacing: 0) {
                                    ShiftCard(shift: shift)
                                        .padding(.horizontal)
                                    
                                    // Кнопка в отдельном контейнере
                                    if shift.employeeId != currentUserId {
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                if pendingRequests.contains(shift.id) {
                                                    cancelRequest(shift)
                                                } else {
                                                    requestShift(shift)
                                                }
                                            }) {
                                                Text(pendingRequests.contains(shift.id) ? "Отменить запрос" : "Принять смену")
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 12)
                                                    .background(pendingRequests.contains(shift.id) ? Color.orange : Color.blue)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemBackground))
                                    } else {
                                        HStack {
                                            Spacer()
                                            Text("Ваша смена")
                                                .fontWeight(.medium)
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                        }
                                        .padding(.horizontal)
                                        .background(Color(.systemBackground))
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Секция моих смен
                    Section(header: Text("Мои смены")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)) {
                        if myShifts.isEmpty {
                            Text("У вас нет смен")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(sortedDates, id: \.self) { date in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(formatDateHeader(date))
                                        .font(.headline)
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                    
                                    ForEach(myShifts[date] ?? []) { shift in
                                        VStack(spacing: 0) {
                                            ShiftCard(shift: shift)
                                                .padding(.horizontal)
                                            
                                            // Кнопка обмена
                                            HStack {
                                                Spacer()
                                                Button(action: {
                                                    if pendingExchanges.contains(shift.id) {
                                                        cancelExchange(shift)
                                                    } else {
                                                        selectedShift = shift
                                                        showingOfferSheet = true
                                                    }
                                                }) {
                                                    Text(pendingExchanges.contains(shift.id) ? "Отменить обмен" : "Предложить обмен")
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 20)
                                                        .padding(.vertical, 12)
                                                        .background(pendingExchanges.contains(shift.id) ? Color.orange : Color.green)
                                                        .cornerRadius(8)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 12)
                                            .background(Color(.systemBackground))
                                        }
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Обмен сменами")
        .onAppear {
            if let userId = Auth.auth().currentUser?.uid {
                currentUserId = userId
                fetchOpenShifts()
                fetchMyShifts()
                fetchPendingRequests()
                fetchPendingExchanges()
            }
        }
        .sheet(isPresented: $showingOfferSheet) {
            if let shift = selectedShift {
                OfferShiftView(shift: shift, onDismiss: {
                    showingOfferSheet = false
                    fetchOpenShifts()
                    fetchMyShifts()
                    fetchPendingExchanges()
                })
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Уведомление"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func formatDateHeader(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMMM yyyy"
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
    
    private func requestShift(_ shift: WorkShift) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        print("🔄 Начало процесса принятия смены")
        
        // Получаем данные текущего пользователя
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка получения данных пользователя: \(error.localizedDescription)")
                return
            }
            
            guard let userData = document?.data(),
                  let userName = userData["name"] as? String else {
                print("❌ Не найдены данные пользователя")
                return
            }
            
            // Создаем запись о принятии смены
            let acceptData: [String: Any] = [
                "shiftId": shift.id,
                "employeeId": userId,
                "employeeName": userName,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "pending"
            ]
            
            db.collection("shiftExchangeAccepts").addDocument(data: acceptData) { error in
                if let error = error {
                    print("❌ Ошибка при создании записи о принятии: \(error.localizedDescription)")
                    alertMessage = "Произошла ошибка при отправке запроса"
                } else {
                    print("✅ Запись о принятии смены создана успешно")
                    alertMessage = "Ваш запрос отправлен и находится на рассмотрении"
                    pendingRequests.insert(shift.id)
                }
                showAlert = true
            }
        }
    }
    
    private func cancelRequest(_ shift: WorkShift) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        print("🔄 Начало процесса отмены принятия смены")
        
        db.collection("shiftExchangeAccepts")
            .whereField("shiftId", isEqualTo: shift.id)
            .whereField("employeeId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Ошибка при отмене принятия: \(error.localizedDescription)")
                    alertMessage = "Произошла ошибка при отмене запроса"
                    showAlert = true
                    return
                }
                
                guard let document = snapshot?.documents.first else { return }
                
                document.reference.delete { error in
                    if let error = error {
                        print("❌ Ошибка при удалении записи: \(error.localizedDescription)")
                        alertMessage = "Произошла ошибка при отмене запроса"
                    } else {
                        print("✅ Запись о принятии смены удалена успешно")
                        alertMessage = "Запрос успешно отменен"
                        pendingRequests.remove(shift.id)
                    }
                    showAlert = true
                }
            }
    }
    
    private func fetchOpenShifts() {
        isLoading = true
        print("🔄 Начало загрузки данных")
        
        let db = Firestore.firestore()
        print("🔍 Начинаем загрузку доступных смен")
        
        db.collection("shiftExchangeOffers")
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Ошибка при загрузке предложений: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                
                let shiftIds = snapshot?.documents.compactMap { $0.data()["shiftId"] as? String } ?? []
                print("📝 Найдено предложений: \(shiftIds.count)")
                
                if shiftIds.isEmpty {
                    print("📭 Нет доступных смен")
                    self.openShifts = []
                    self.isLoading = false
                    return
                }
                
                db.collection("shifts")
                    .whereField(FieldPath.documentID(), in: shiftIds)
                    .getDocuments { shiftsSnapshot, shiftsError in
                        defer {
                            self.isLoading = false
                            print("🏁 Загрузка завершена, isLoading = false")
                        }
                        
                        if let shiftsError = shiftsError {
                            print("❌ Ошибка при загрузке смен: \(shiftsError.localizedDescription)")
                            return
                        }
                        
                        self.openShifts = shiftsSnapshot?.documents.compactMap { document in
                            let data = document.data()
                            print("📄 Обработка смены: \(document.documentID)")
                            
                            guard let startTime = data["startTime"] as? Timestamp,
                                  let endTime = data["endTime"] as? Timestamp,
                                  let date = data["date"] as? String else {
                                print("⚠️ Пропущена смена из-за отсутствия обязательных полей")
                                return nil
                            }
                            
                            return WorkShift(
                                id: document.documentID,
                                employeeName: data["employeeName"] as? String ?? "",
                                specialty: data["specialty"] as? String ?? "",
                                startTime: startTime,
                                endTime: endTime,
                                breakTime: data["breakTime"] as? Int ?? 0,
                                zone: data["zone"] as? String ?? "",
                                date: date,
                                employeeId: data["employeeId"] as? String
                            )
                        } ?? []
                        
                        // Сортируем смены по дате и времени
                        self.openShifts.sort { shift1, shift2 in
                            if shift1.date == shift2.date {
                                return shift1.startTime.dateValue() < shift2.startTime.dateValue()
                            }
                            return shift1.date < shift2.date
                        }
                        
                        print("✅ Загружено доступных смен: \(self.openShifts.count)")
                    }
            }
    }
    
    private func fetchMyShifts() {
        print("🔄 Начало загрузки моих смен")
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: пользователь не авторизован")
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("shifts")
            .whereField("employeeId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Ошибка при загрузке смен: \(error.localizedDescription)")
                    return
                }
                
                var loadedShifts: [String: [WorkShift]] = [:]
                print("📄 Обработка моих смен")
                
                // Получаем текущую дату
                let currentDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let currentDateString = dateFormatter.string(from: currentDate)
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    
                    guard let startTime = data["startTime"] as? Timestamp,
                          let endTime = data["endTime"] as? Timestamp,
                          let date = data["date"] as? String else {
                        print("⚠️ Пропущена смена из-за отсутствия обязательных полей")
                        continue
                    }
                    
                    // Фильтруем смены по дате
                    if date >= currentDateString {
                        let shift = WorkShift(
                            id: document.documentID,
                            employeeName: data["employeeName"] as? String ?? "",
                            specialty: data["specialty"] as? String ?? "",
                            startTime: startTime,
                            endTime: endTime,
                            breakTime: data["breakTime"] as? Int ?? 0,
                            zone: data["zone"] as? String ?? "",
                            date: date,
                            employeeId: userId
                        )
                        
                        loadedShifts[date, default: []].append(shift)
                    }
                }
                
                // Сортируем смены внутри каждой даты
                for (date, shifts) in loadedShifts {
                    loadedShifts[date] = shifts.sorted { $0.startTime.dateValue() < $1.startTime.dateValue() }
                }
                
                self.myShifts = loadedShifts
                print("✅ Загружено моих смен: \(loadedShifts.values.map { $0.count }.reduce(0, +))")
            }
    }
    
    private func fetchPendingRequests() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        db.collection("shiftExchangeAccepts")
            .whereField("employeeId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Ошибка при загрузке принятых запросов: \(error.localizedDescription)")
                    return
                }
                
                self.pendingRequests = Set(snapshot?.documents.compactMap { $0.data()["shiftId"] as? String } ?? [])
                print("✅ Загружено принятых запросов: \(self.pendingRequests.count)")
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
                    print("❌ Ошибка при загрузке запросов на обмен: \(error.localizedDescription)")
                    return
                }
                
                self.pendingExchanges = Set(snapshot?.documents.compactMap { $0.data()["shiftId"] as? String } ?? [])
                print("✅ Загружено запросов на обмен: \(self.pendingExchanges.count)")
            }
    }
    
    private func cancelExchange(_ shift: WorkShift) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        print("🔄 Начало процесса отмены обмена")
        
        db.collection("shiftExchangeOffers")
            .whereField("shiftId", isEqualTo: shift.id)
            .whereField("employeeId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Ошибка при отмене обмена: \(error.localizedDescription)")
                    alertMessage = "Произошла ошибка при отмене обмена"
                    showAlert = true
                    return
                }
                
                guard let document = snapshot?.documents.first else { return }
                
                document.reference.delete { error in
                    if let error = error {
                        print("❌ Ошибка при удалении обмена: \(error.localizedDescription)")
                        alertMessage = "Произошла ошибка при отмене обмена"
                    } else {
                        print("✅ Запрос на обмен успешно отменен")
                        alertMessage = "Обмен успешно отменен"
                        pendingExchanges.remove(shift.id)
                    }
                    showAlert = true
                }
            }
    }
    
    // Обновляем отображение карточки смены
    private func ShiftCard(shift: WorkShift) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Зона и время
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(shift.zone)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                        Text("\(formatTime(shift.startTime.dateValue())) - \(formatTime(shift.endTime.dateValue()))")
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            
            Divider()
            
            // Информация о сотруднике и смене
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                    Text(shift.employeeName)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Image(systemName: "briefcase")
                        .foregroundColor(.gray)
                    Text(shift.specialty)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text(formatDate(shift.date))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
}
