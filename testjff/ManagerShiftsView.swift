//import SwiftUI
//import Firebase
//
//struct ManagerShiftsView: View {
//    @StateObject private var checkInService = ShiftCheckInService.shared
//    @State private var shifts: [WorkShift] = []
//    @State private var showAlert = false
//    @State private var alertMessage = ""
//    @State private var isLoading = true
//    @State private var selectedZone: String?
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Заголовок
//            HStack {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Смены на сегодня")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                    Text(formatDate(Date()))
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//                Spacer()
//            }
//            .padding(.horizontal)
//            
//            if isLoading {
//                ProgressView()
//                    .scaleEffect(1.5)
//                    .padding()
//            } else if shifts.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: "calendar.badge.exclamationmark")
//                        .font(.system(size: 50))
//                        .foregroundColor(.gray)
//                    Text("Нет смен на сегодня")
//                        .font(.headline)
//                        .foregroundColor(.gray)
//                }
//                .frame(maxHeight: .infinity)
//                .padding()
//            } else {
//                // Фильтр по зонам
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 12) {
//                        ForEach(Array(Set(shifts.map { $0.zone })), id: \.self) { zone in
//                            Button(action: {
//                                selectedZone = selectedZone == zone ? nil : zone
//                            }) {
//                                Text(zone)
//                                    .padding(.horizontal, 16)
//                                    .padding(.vertical, 8)
//                                    .background(selectedZone == zone ? Color.blue : Color.gray.opacity(0.2))
//                                    .foregroundColor(selectedZone == zone ? .white : .primary)
//                                    .cornerRadius(20)
//                            }
//                        }
//                    }
//                    .padding(.horizontal)
//                }
//                
//                // Список смен
//                ScrollView {
//                    LazyVStack(spacing: 16) {
//                        ForEach(filteredShifts) { shift in
//                            VStack(alignment: .leading, spacing: 8) {
//                                Text(shift.employeeName)
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
//                                    .padding(.horizontal)
//                                
//                                ShiftCard(
//                                    shift: shift,
//                                    checkInService: checkInService
//                                )
//                                .padding(.horizontal)
//                            }
//                        }
//                    }
//                    .padding(.horizontal)
//                }
//            }
//        }
//        .padding(.vertical)
//        .onAppear {
//            loadShifts()
//        }
//        .alert(isPresented: $showAlert) {
//            Alert(
//                title: Text("Уведомление"),
//                message: Text(alertMessage),
//                dismissButton: .default(Text("OK"))
//            )
//        }
//    }
//    
//    private var filteredShifts: [WorkShift] {
//        if let selectedZone = selectedZone {
//            return shifts.filter { $0.zone == selectedZone }
//        }
//        return shifts
//    }
//    
//    private func loadShifts() {
//        isLoading = true
//        checkInService.getTodayShifts { loadedShifts in
//            shifts = loadedShifts.sorted { $0.startTime.dateValue() < $1.startTime.dateValue() }
//            isLoading = false
//        }
//    }
//    
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "d MMMM yyyy"
//        formatter.locale = Locale(identifier: "ru_RU")
//        return formatter.string(from: date)
//    }
//}
//
//struct ShiftCard: View {
//    let shift: WorkShift
//    let checkInService: ShiftCheckInService
//    @State private var showAlert = false
//    @State private var alertMessage = ""
//    @State private var showCancelConfirmation = false
//    @State private var actionToCancel: (() -> Void)?
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            // Информация о сотруднике
//            HStack {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(shift.employeeName)
//                        .font(.headline)
//                    Text(shift.specialty)
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//                Spacer()
//                
//                // Статус смены
//                HStack {
//                    Circle()
//                        .fill(statusColor)
//                        .frame(width: 8, height: 8)
//                    Text(statusText)
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                }
//            }
//            
//            // Время и зона
//            HStack {
//                Image(systemName: "clock")
//                    .foregroundColor(.blue)
//                Text("\(formatTime(shift.startTime)) - \(formatTime(shift.endTime))")
//                
//                Spacer()
//                
//                Image(systemName: "mappin.circle")
//                    .foregroundColor(.blue)
//                Text(shift.zone)
//            }
//            .font(.subheadline)
//            
//            // Кнопки действий
//            if shift.status == "scheduled" {
//                Button(action: {
//                    checkInService.managerCheckIn(shiftId: shift.id) { success, error in
//                        if success {
//                            showAlert(message: "Сотрудник отмечен на смене")
//                        } else {
//                            showAlert(message: error ?? "Произошла ошибка")
//                        }
//                    }
//                }) {
//                    HStack {
//                        Image(systemName: "checkmark.circle.fill")
//                        Text("Отметить на смене")
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.green)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                }
//            } else if shift.status == "started" {
//                Button(action: {
//                    checkInService.managerCheckOut(shiftId: shift.id) { success, error in
//                        if success {
//                            showAlert(message: "Смена завершена")
//                        } else {
//                            showAlert(message: error ?? "Произошла ошибка")
//                        }
//                    }
//                }) {
//                    HStack {
//                        Image(systemName: "xmark.circle.fill")
//                        Text("Завершить смену")
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.red)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                }
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
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
//        switch shift.status {
//        case "scheduled":
//            return .orange
//        case "started":
//            return .green
//        case "completed":
//            return .gray
//        default:
//            return .gray
//        }
//    }
//    
//    private var statusText: String {
//        switch shift.status {
//        case "scheduled":
//            return "Ожидает"
//        case "started":
//            return "На смене"
//        case "completed":
//            return "Завершена"
//        default:
//            return "Неизвестно"
//        }
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
