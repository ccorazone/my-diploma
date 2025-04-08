import SwiftUI
import Firebase
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authState: AuthState // Доступ к глобальному состоянию
    @State private var isLoading: Bool = true // Индикатор загрузки

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Загрузка...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5, anchor: .center)
            } else {
                if authState.isLoggedIn {
                    // Если пользователь авторизован, открываем соответствующую панель
                    if let role = authState.userRole {
                        if role == "manager" {
                            AdminDashboardView() // Панель администратора
                        } else if role == "employee" {
                            EmployeeDashboardView() // Панель сотрудника
                        } else {
                            ErrorView(message: "Ошибка: Неизвестная роль пользователя")
                        }
                    }
                } else {
                    // Начальный экран регистрации и входа
                    NavigationView {
                        VStack(spacing: 20) {
                            Text("Добро пожаловать!")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()

                            Spacer()

                            NavigationLink(destination: RegisterCompanyView()) {
                                Text("Регистрация компании")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .green]), startPoint: .leading, endPoint: .trailing))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal)

                            NavigationLink(destination: RegisterView()) {
                                Text("Регистрация сотрудника")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LinearGradient(gradient: Gradient(colors: [.green, .blue]), startPoint: .leading, endPoint: .trailing))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal)

                            NavigationLink(destination: LoginView(onLogin: {
                                checkAuthState() // Проверяем авторизацию
                            })) {
                                Text("Вход")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LinearGradient(gradient: Gradient(colors: [.blue, .green]), startPoint: .leading, endPoint: .trailing))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal)

                            Button(action: {
                                // Действие для "Забыли пароль?"
                            }) {
                                Text("Забыли пароль?")
                                    .foregroundColor(.white)
                                    .underline()
                            }
                            .padding(.top)

                            Spacer()
                        }
                        .padding()
                        .background(
                            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                .ignoresSafeArea() // Устанавливаем фон на весь экран
                        )
                    }
                }
            }
        }
        .onAppear {
            checkAuthState()
        }
    }

    // Проверка состояния авторизации
    func checkAuthState() {
        if let currentUser = Auth.auth().currentUser {
            // Передаём userId в функцию fetchUserRole
            fetchUserRole(for: currentUser.uid)
        } else {
            isLoading = false
            authState.isLoggedIn = false
        }
    }

    // Получение роли пользователя
    func fetchUserRole(for userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Ошибка загрузки роли: \(error.localizedDescription)")
                authState.userRole = nil
            } else if let document = document, document.exists {
                authState.userRole = document.data()?["role"] as? String
                authState.isLoggedIn = true
            } else {
                authState.userRole = nil
            }
            isLoading = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ErrorView: View {
    var message: String

    var body: some View {
        VStack {
            Text(message)
                .font(.title)
                .foregroundColor(.red)
                .padding()
            Spacer()
        }
    }
}
