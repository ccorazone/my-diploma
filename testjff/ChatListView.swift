import SwiftUI
import Firebase
import FirebaseAuth

struct ChatListView: View {
    @State private var employees: [AppUser] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmployee: AppUser?
    @State private var showChat = false
    @State private var currentUserRole: String = "employee"
    @State private var searchText = ""
    
    var sortedEmployees: [AppUser] {
        // Фильтруем текущего пользователя
        let filteredEmployees = employees.filter { $0.id != Auth.auth().currentUser?.uid }
        
        // Сортируем: сначала менеджеры, потом сотрудники, внутри групп по алфавиту
        return filteredEmployees.sorted { first, second in
            if first.role == second.role {
                return first.name.lowercased() < second.name.lowercased()
            }
            return first.role == "manager"
        }
    }
    
    var displayedEmployees: [AppUser] {
        var filtered = currentUserRole == "manager" ? sortedEmployees : sortedEmployees.filter { $0.role == "manager" }
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.email.lowercased().contains(searchText.lowercased())
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Поисковая строка
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Поиск по имени или email", text: $searchText)
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
                    ProgressView("Загрузка...")
                        .padding()
                } else if displayedEmployees.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        if searchText.isEmpty {
                            Text("Нет доступных сотрудников")
                        } else {
                            Text("Ничего не найдено")
                            Text("Попробуйте изменить параметры поиска")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(displayedEmployees) { employee in
                            Button(action: {
                                selectedEmployee = employee
                                showChat = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(employee.name.isEmpty ? "Без имени" : employee.name)
                                            .font(.headline)
                                        HStack {
                                            Text(employee.role == "manager" ? "Менеджер" : "Сотрудник")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(employee.role == "manager" ? Color.blue : Color.gray)
                                                .cornerRadius(8)
                                            Text(employee.email)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "message.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Выберите сотрудника")
            .navigationBarItems(trailing: Button("Закрыть") {
                dismiss()
            })
        }
        .sheet(isPresented: $showChat) {
            if let employee = selectedEmployee {
                ChatView(employee: employee)
            }
        }
        .onAppear {
            fetchCurrentUserRole()
        }
    }
    
    private func fetchCurrentUserRole() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document,
               let role = document.data()?["role"] as? String,
               let companyId = document.data()?["companyId"] as? String {
                self.currentUserRole = role
                fetchEmployees(companyId: companyId)
            }
        }
    }
    
    private func fetchEmployees(companyId: String) {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Ошибка загрузки сотрудников: \(error.localizedDescription)")
                } else {
                    employees = snapshot?.documents.compactMap { doc in
                        guard let data = doc.data() as? [String: Any] else { return nil }
                        return AppUser(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "",
                            email: data["email"] as? String ?? "",
                            role: data["role"] as? String ?? "employee",
                            specialty: data["specialty"] as? String ?? ""
                        )
                    } ?? []
                }
                isLoading = false
            }
    }
}


