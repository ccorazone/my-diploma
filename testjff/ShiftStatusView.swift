//import SwiftUI
//import Firebase
//
//struct ShiftStatusView: View {
//    @StateObject private var checkInService = ShiftCheckInService.shared
//    @State private var showAlert = false
//    @State private var alertMessage = ""
//    @State private var showCancelConfirmation = false
//    @State private var actionToCancel: (() -> Void)?
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Заголовок с приветствием
//            HStack {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Добро пожаловать!")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                    Text(getUserName())
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//                Spacer()
//            }
//            .padding(.horizontal)
//            
//            // Основная карточка статуса
//            VStack(spacing: 15) {
//                if let shift = checkInService.currentShift {
//                    // Информация о смене
//                    VStack(alignment: .leading, spacing: 12) {
//                        HStack {
//                            Image(systemName: "calendar")
//                                .foregroundColor(.blue)
//                            Text(formatDate(shift.date))
//                                .font(.headline)
//                        }
//                        
//                        HStack {
//                            Image(systemName: "clock")
//                                .foregroundColor(.blue)
//                            Text("\(formatTime(shift.startTime)) - \(formatTime(shift.endTime))")
//                                .font(.headline)
//                        }
//                        
//                        HStack {
//                            Image(systemName: "mappin.circle")
//                                .foregroundColor(.blue)
//                            Text(shift.zone)
//                                .font(.headline)
//                        }
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding()
//                    .background(Color.blue.opacity(0.1))
//                    .cornerRadius(12)
//                    
//                    // Статус смены
//                    HStack {
//                        Circle()
//                            .fill(statusColor)
//                            .frame(width: 12, height: 12)
//                        Text(statusText)
//                            .font(.headline)
//                    }
//                    .padding(.vertical, 8)
//                    
//                    // Кнопки действий
//                    HStack(spacing: 15) {
//                        if checkInService.checkInStatus == .canCheckIn {
//                            Button(action: {
//                                checkInService.checkIn { success, error in
//                                    if success {
//                                        showAlert(message: "Вы успешно отметились на смене")
//                                    } else {
//                                        showAlert(message: error ?? "Произошла ошибка")
//                                    }
//                                }
//                            }) {
//                                HStack {
//                                    Image(systemName: "checkmark.circle.fill")
//                                    Text("Отметиться")
//                                }
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color.green)
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                            }
//                        } else if checkInService.checkInStatus == .checkedIn {
//                            Button(action: {
//                                checkInService.checkOut { success, error in
//                                    if success {
//                                        showAlert(message: "Смена успешно завершена")
//                                    } else {
//                                        showAlert(message: error ?? "Произошла ошибка")
//                                    }
//                                }
//                            }) {
//                                HStack {
//                                    Image(systemName: "xmark.circle.fill")
//                                    Text("Завершить смену")
//                                }
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color.red)
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                            }
//                        }
//                    }
//                    .padding(.horizontal)
//                } else {
//                    Text("Нет активных смен на сегодня")
//                        .font(.headline)
//                        .foregroundColor(.gray)
//                        .padding()
//                }
//            }
//            .padding()
//            .background(Color.white)
//            .cornerRadius(15)
//            .shadow(radius: 5)
//            .padding(.horizontal)
//        }
//        .padding(.vertical)
//        .onAppear {
//            checkInService.checkCurrentShift()
//        }
//        .alert(isPresented: $showAlert) {
//            Alert(
//                title: Text("Уведомление"),
//                message: Text(alertMessage),
//                dismissButton: .default(Text("OK"))
//            )
//        }
//        .alert(isPresented: $showCancelConfirmation) {
//            Alert(
//                title: Text("Подтверждение"),
//                message: Text("Вы уверены, что хотите отменить это действие?"),
//                primaryButton: .destructive(Text("Отменить")) {
//                    actionToCancel?()
//                },
//                secondaryButton: .cancel(Text("Нет"))
//            )
//        }
//    }
//    
//    private var statusColor: Color {
//        switch checkInService.checkInStatus {
//        case .noShift:
//            return .gray
//        case .waiting:
//            return .orange
//        case .canCheckIn:
//            return .green
//        case .checkedIn:
//            return .blue
//        case .completed:
//            return .gray
//        case .error:
//            return .red
//        }
//    }
//    
//    private var statusText: String {
//        switch checkInService.checkInStatus {
//        case .noShift:
//            return "Нет активных смен"
//        case .waiting:
//            if let shift = checkInService.currentShift {
//                let now = Date()
//                let startTime = shift.startTime.dateValue()
//                if now > startTime {
//                    return "Смена пропущена"
//                }
//                return "Ожидание начала смены"
//            }
//            return "Ожидание"
//        case .canCheckIn:
//            return "Можно отметиться"
//        case .checkedIn:
//            return "На смене"
//        case .completed:
//            return "Смена завершена"
//        case .error(let message):
//            return "Ошибка: \(message)"
//        }
//    }
//    
//    private func getUserName() -> String {
//        if let user = Auth.auth().currentUser {
//            return user.displayName ?? user.email ?? "Пользователь"
//        }
//        return "Пользователь"
//    }
//    
//    private func formatDate(_ dateString: String) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd"
//        formatter.locale = Locale(identifier: "ru_RU")
//        
//        guard let date = formatter.date(from: dateString) else { return dateString }
//        
//        formatter.dateFormat = "d MMMM yyyy"
//        return formatter.string(from: date)
//    }
//    
//    private func formatTime(_ timestamp: Timestamp) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm"
//        return formatter.string(from: timestamp.dateValue())
//    }
//    
//    private func showAlert(message: String) {
//        alertMessage = message
//        showAlert = true
//    }
//}
