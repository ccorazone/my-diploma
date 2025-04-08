import SwiftUI
import Firebase
import FirebaseAuth

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var companyId = ""
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea() // Устанавливаем фон на весь экран

            VStack(spacing: 20) {
                Text("Регистрация сотрудника")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal)

                SecureField("Пароль", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                SecureField("Подтвердите пароль", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                TextField("ID компании", text: $companyId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button(action: registerEmployee) {
                    Text("Зарегистрироваться")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.green, .blue]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }

    func registerEmployee() {
        if password != confirmPassword {
            errorMessage = "Пароли не совпадают"
            return
        }
        
        // Create user with email and password
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                return
            }

            // Successfully created user, now save to Firestore
            guard let userId = authResult?.user.uid else {
                errorMessage = "Ошибка: Не удалось получить идентификатор пользователя"
                return
            }

            let userData: [String: Any] = [
                "email": email,
                "role": "employee",
                "companyId": companyId
            ]

            let db = Firestore.firestore()
            db.collection("users").document(userId).setData(userData) { error in
                if let error = error {
                    errorMessage = "Ошибка сохранения данных пользователя: \(error.localizedDescription)"
                } else {
                    errorMessage = "Сотрудник успешно зарегистрирован!"
                }
            }
        }
    }
}
