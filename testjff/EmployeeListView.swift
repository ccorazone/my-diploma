import SwiftUI
import Firebase
import FirebaseAuth

struct EmployeeListView: View {
    @State private var employees: [AppUser] = [] // Список сотрудников
    @State private var isLoading = true // Индикатор загрузки
    @State private var showAddEmployeeSheet = false // Для добавления сотрудников
    @State private var searchText = ""
    
    @State private var employeeToDelete: AppUser?
    @State private var showDeleteAlert = false
    @State private var selectedEmployee: AppUser?
    @State private var showChatList = false
    @State private var showEditView = false
    @State private var showDetailView = false
    let selectedTab: Int
    
    var filteredEmployees: [AppUser] {
        if searchText.isEmpty {
            return employees
        }
        return employees.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.email.lowercased().contains(searchText.lowercased()) ||
            $0.specialty.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                // Поисковая строка
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Поиск по имени, email или должности", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                if isLoading {
                    ProgressView("Загрузка сотрудников...")
                } else {
                    if filteredEmployees.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            if searchText.isEmpty {
                                Text("Нет сотрудников")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            } else {
                                Text("Ничего не найдено")
                                    .font(.headline)
                                Text("Попробуйте изменить параметры поиска")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredEmployees) { employee in
                                NavigationLink(destination: EmployeeDetailView(employee: employee)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(employee.name.isEmpty ? "Без имени" : employee.name)
                                                .font(.headline)
                                            Text(employee.email)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Text(employee.specialty)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Spacer()
                                        
                                        // Меню действий
                                        Menu {
                                            Button(action: {
                                                selectedEmployee = employee
                                                showEditView = true
                                            }) {
                                                Label("Редактировать", systemImage: "pencil")
                                            }
                                            
                                            Button(action: {
                                                updateEmployeeRole(employee)
                                            }) {
                                                Label("Сделать администратором", systemImage: "person.badge.key")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                showDeleteConfirmation(employee)
                                            }) {
                                                Label("Удалить сотрудника", systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Сотрудники")
            .toolbar {
                if selectedTab == 1 { // Показываем кнопку только на вкладке "Сотрудники"
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showChatList = true
                        }) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showChatList) {
            ChatListView()
        }
        .sheet(isPresented: $showEditView) {
            if let employee = selectedEmployee {
                EmployeeEditView(employee: employee)
            }
        }
        .navigationDestination(isPresented: $showDetailView) {
            if let employee = selectedEmployee {
                EmployeeDetailView(employee: employee)
            }
        }
        .onAppear {
            isLoading = true  // ✅ Перед загрузкой показываем "Загрузка сотрудников..."
            fetchEmployees()
        }

        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Удаление сотрудника"),
                message: Text("Вы уверены, что хотите удалить сотрудника? Это действие нельзя отменить."),
                primaryButton: .destructive(Text("Удалить")) {
                    if let employee = employeeToDelete {
                        deleteEmployee(employee)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    func updateEmployeeRole(_ employee: AppUser) {
        let db = Firestore.firestore()
        
        db.collection("users").document(employee.id).updateData([
            "role": "manager"
        ]) { error in
            if let error = error {
                print("❌ Ошибка обновления роли: \(error.localizedDescription)")
            } else {
                print("✅ \(employee.email) теперь администратор")
                fetchEmployees()
            }
        }
    }

    func showDeleteConfirmation(_ employee: AppUser) {
        employeeToDelete = employee
        showDeleteAlert = true
    }

    func deleteEmployee(_ employee: AppUser) {
        let db = Firestore.firestore()
        
        db.collection("users").document(employee.id).delete { error in
            if let error = error {
                print("❌ Ошибка удаления: \(error.localizedDescription)")
            } else {
                print("✅ \(employee.email) удален")
                fetchEmployees()
            }
        }
    }

    func fetchEmployees() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            return
        }

        print("📡 Загружаем сотрудников для userId: \(userId)")

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка получения companyId: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists,
               let companyId = document.data()?["companyId"] as? String {
                
                print("✅ Найден companyId: \(companyId)")

                db.collection("users")
                    .whereField("companyId", isEqualTo: companyId)
                    .whereField("role", isEqualTo: "employee")
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("❌ Ошибка загрузки сотрудников: \(error.localizedDescription)")
                        } else {
                            let fetchedEmployees: [AppUser] = snapshot?.documents.compactMap { doc in
                                guard let data = doc.data() as? [String: Any] else {
                                    print("⚠️ Ошибка парсинга данных сотрудника: \(doc.documentID)")
                                    return nil
                                }

                                return AppUser(
                                    id: doc.documentID,
                                    name: data["name"] as? String ?? "",
                                    email: data["email"] as? String ?? "Неизвестный Email",
                                    role: data["role"] as? String ?? "employee",
                                    specialty: data["specialty"] as? String ?? "Не указано"
                                )
                            } ?? []

                            
                            print("✅ Загружено сотрудников: \(fetchedEmployees.count)")

                            // 🔹 Обновляем UI в основном потоке
                            DispatchQueue.main.async {
                                self.employees = fetchedEmployees
                                self.isLoading = false  // ✅ Убираем "Загрузка сотрудников..."
                            }
                        }
                    }
            } else {
                print("❌ Не найден companyId у пользователя \(userId)")
            }
        }
    }


}

// // Модель пользователя
// struct AppUser: Identifiable {
//     var id: String
//     var email: String
//     var role: String
//     var specialty: String
//     var name: String
// }
