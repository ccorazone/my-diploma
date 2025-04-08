import SwiftUI
import Firebase
import FirebaseAuth

struct OfferShiftView: View {
    let shift: WorkShift
    let onDismiss: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Информация о смене").textCase(.none)) {
                        ShiftInfoRow(imageName: "calendar", color: .blue, text: "Дата: \(formatDate(shift.date))")
                        ShiftInfoRow(imageName: "clock", color: .blue, text: "Время: \(formatTime(shift.startTime)) - \(formatTime(shift.endTime))")
                        ShiftInfoRow(imageName: "person.fill", color: .blue, text: "Сотрудник: \(shift.employeeName)")
                        if !shift.zone.isEmpty {
                            ShiftInfoRow(imageName: "mappin.circle.fill", color: .blue, text: "Зона: \(shift.zone)")
                        }
                    }
                    
                    Section(header: Text("Сообщение").textCase(.none)) {
                        TextEditor(text: $message)
                            .frame(height: 100)
                    }
                }
                
                Button(action: submitOffer) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Отправка..." : "Предложить обмен")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding()
            }
            .navigationBarTitle("Предложить обмен", displayMode: .inline)
            .navigationBarItems(trailing: Button("Отмена") {
                presentationMode.wrappedValue.dismiss()
                onDismiss()
            })
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Уведомление"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("успешно") {
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }
                }
            )
        }
    }
    
    private func submitOffer() {
        print("🔄 Начало отправки предложения об обмене")
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: пользователь не авторизован")
            showAlert(message: "Ошибка: не удалось определить пользователя")
            return
        }
        
        isLoading = true
        let db = Firestore.firestore()
        
        // Получаем информацию о текущем пользователе
        db.collection("users").document(userId).getDocument { userSnapshot, error in
            if let error = error {
                print("❌ Ошибка при получении данных пользователя: \(error.localizedDescription)")
                handleError(error)
                return
            }
            
            guard let userData = userSnapshot?.data(),
                  let userName = userData["name"] as? String else {
                print("❌ Ошибка: не удалось получить имя пользователя")
                showAlert(message: "Ошибка: не удалось получить данные пользователя")
                isLoading = false
                return
            }
            
            // Создаем предложение об обмене
            let offerData: [String: Any] = [
                "shiftId": shift.id,
                "employeeId": userId,
                "employeeName": userName,
                "message": message,
                "status": "pending",
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            print("📝 Создание предложения об обмене")
            db.collection("shiftExchangeOffers").addDocument(data: offerData) { error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("❌ Ошибка при создании предложения: \(error.localizedDescription)")
                        handleError(error)
                        return
                    }
                    
                    print("✅ Предложение об обмене успешно создано")
                    showAlert(message: "Предложение об обмене успешно отправлено")
                }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            isLoading = false
            showAlert(message: "Произошла ошибка: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async {
            alertMessage = message
            showAlert = true
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp.dateValue())
    }
}

struct ShiftInfoRow: View {
    let imageName: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: imageName)
                .foregroundColor(color)
            Text(text)
        }
    }
}


