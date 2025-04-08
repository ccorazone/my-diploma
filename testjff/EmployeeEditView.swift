import SwiftUI
import Firebase

struct EmployeeEditView: View {
    var employee: AppUser

    @State private var selectedSpecialty: String
    @State private var customSpecialty: String = ""
    @Environment(\.presentationMode) var presentationMode

    // 🔹 Разделение специальностей по категориям
    let specialties = [
        "Кухня": ["Повар", "Шеф-повар", "Су-шеф", "Пекарь", "Кондитер", "Кухонный работник", "Посудомойщик"],
        "Зал ресторана": ["Официант", "Бармен", "Хостес", "Раннер", "Арт-директор", "Менеджер зала"],
        "Отель": ["Горничная", "Ресепшен", "Беллбой", "Охранник", "Клинер"],
        "Магазин": ["Кассир", "Консультант", "Мерчендайзер", "заведующий отделом магазина"],
        "Кофейня": ["Бариста", "Кондитер"]
    ]
    
    let categoryTitles = ["Кухня", "Зал ресторана", "Отель","Магазин", "Кофейня"]

    init(employee: AppUser) {
        self.employee = employee
        _selectedSpecialty = State(initialValue: employee.specialty) // Устанавливаем текущую специальность
    }

    var body: some View {
        VStack {
            Text("Редактировать сотрудника")
                .font(.largeTitle)
                .padding()

            Text(employee.email)
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.bottom, 10)

            Text("Выберите специальность:")
                .font(.subheadline)
                .padding(.bottom, 5)

            List {
                ForEach(categoryTitles, id: \.self) { category in
                    Section(header: Text(category).font(.headline)) {
                        if let positions = specialties[category] {
                            ForEach(positions, id: \.self) { specialty in
                                Button(action: {
                                    selectedSpecialty = specialty
                                }) {
                                    HStack {
                                        Text(specialty)
                                        Spacer()
                                        if selectedSpecialty == specialty {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 🔹 Опция "Другое"
                Section {
                    Button(action: {
                        selectedSpecialty = "custom"
                    }) {
                        HStack {
                            Text("Другое (ввести вручную)")
                            Spacer()
                            if selectedSpecialty == "custom" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if selectedSpecialty == "custom" {
                        TextField("Введите специальность", text: $customSpecialty)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                    }
                }
            }
            .listStyle(GroupedListStyle())

            Button(action: saveSpecialty) {
                Text("Сохранить")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            Spacer()
        }
    }

    func saveSpecialty() {
        let db = Firestore.firestore()
        let newSpecialty = selectedSpecialty == "custom" ? customSpecialty : selectedSpecialty

        db.collection("users").document(employee.id).updateData([
            "specialty": newSpecialty
        ]) { error in
            if let error = error {
                print("❌ Ошибка обновления специальности: \(error.localizedDescription)")
            } else {
                print("✅ Специальность обновлена для \(employee.email): \(newSpecialty)")
                presentationMode.wrappedValue.dismiss() // Закрываем экран
            }
        }
    }
}
