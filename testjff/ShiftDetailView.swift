import SwiftUI
import Firebase

struct ShiftDetailView: View {
    var shift: WorkShift
    @State private var employees: [AppUser] = []

    var body: some View {
        VStack {
            Text("Детали смены")
                .font(.title)
                .padding()

            Text("\(shift.zone)")
                .font(.headline)

            Text("Время: \(formatTime(shift.startTime)) - \(formatTime(shift.endTime))")
                .font(.subheadline)
                .foregroundColor(.gray)

            Divider()

            Text("Сотрудники на смене")
                .font(.headline)
                .padding(.top)

            if employees.isEmpty {
                Text("Нет данных")
                    .foregroundColor(.gray)
            } else {
                List(employees) { employee in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text(employee.name)
                                .font(.headline)
                            Text(employee.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchEmployees()
        }
    }
    func formatTime(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }


    // 🔹 Загружаем список сотрудников смены
    func fetchEmployees() {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("shifts", arrayContains: shift.id) // Поиск всех сотрудников, у кого есть эта смена
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Ошибка загрузки сотрудников: \(error.localizedDescription)")
                    return
                }

                self.employees = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    return AppUser(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Неизвестно",
                        email: data["email"] as? String ?? "Нет email",
                        role: data["role"] as? String ?? "employee"
                    )
                } ?? []
            }
    }
}
