import SwiftUI
import Firebase

struct EditShiftView: View {
    let shift: WorkShift
    let onShiftUpdated: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedZone: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var isBreakEnabled: Bool = false
    @State private var breakStartTime: Date = Date()
    @State private var breakEndTime: Date = Date()
    
    let zones = ["Кухня", "Зал ресторана", "Отель", "Кофейня", "Магазин"]
    
    init(shift: WorkShift, onShiftUpdated: @escaping () -> Void) {
        print("Инициализация EditShiftView")
        print("Shift ID: \(shift.id)")
        print("Zone: \(shift.zone)")
        
        self.shift = shift
        self.onShiftUpdated = onShiftUpdated
        
        // Инициализируем состояния с значениями по умолчанию
        _selectedZone = State(initialValue: shift.zone)
        _startTime = State(initialValue: shift.startTime.dateValue())
        _endTime = State(initialValue: shift.endTime.dateValue())
        
        let hasBreak = (shift.breakTime ?? 0) > 0
        _isBreakEnabled = State(initialValue: hasBreak)
        
        if hasBreak {
            let breakStart = shift.startTime.dateValue().addingTimeInterval(4 * 3600)
            _breakStartTime = State(initialValue: breakStart)
            _breakEndTime = State(initialValue: breakStart.addingTimeInterval(Double(shift.breakTime ?? 60) * 60))
        } else {
            _breakStartTime = State(initialValue: shift.startTime.dateValue().addingTimeInterval(4 * 3600))
            _breakEndTime = State(initialValue: shift.startTime.dateValue().addingTimeInterval(5 * 3600))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о смене")) {
                    Text("ID смены: \(shift.id)")
                        .font(.caption)
                        .foregroundColor(.gray)
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
                    
                    let duration = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
                    if let hours = duration.hour, let minutes = duration.minute {
                        Text("Длительность: \(hours)ч \(minutes)м")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Перерыв")) {
                    Toggle("Добавить перерыв", isOn: $isBreakEnabled)
                    
                    if isBreakEnabled {
                        DatePicker("Начало перерыва", selection: $breakStartTime, displayedComponents: .hourAndMinute)
                        DatePicker("Конец перерыва", selection: $breakEndTime, displayedComponents: .hourAndMinute)
                        
                        let breakDuration = Calendar.current.dateComponents([.minute], from: breakStartTime, to: breakEndTime)
                        if let minutes = breakDuration.minute {
                            Text("Длительность перерыва: \(minutes) мин")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Редактировать смену")
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Сохранить") {
                    updateShift()
                }
            )
        }
    }
    
    private func updateShift() {
        print("Обновление смены...")
        print("ID смены: \(shift.id)")
        print("Новая зона: \(selectedZone)")
        
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = [
            "zone": selectedZone,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime)
        ]
        
        if isBreakEnabled {
            let breakDuration = Calendar.current.dateComponents([.minute], from: breakStartTime, to: breakEndTime)
            updateData["breakTime"] = breakDuration.minute ?? 0
        } else {
            updateData["breakTime"] = 0
        }
        
        db.collection("shifts").document(shift.id).updateData(updateData) { error in
            if let error = error {
                print("❌ Ошибка обновления смены: \(error.localizedDescription)")
            } else {
                print("✅ Смена успешно обновлена")
                onShiftUpdated()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
