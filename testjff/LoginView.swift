import SwiftUI
import Firebase
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var onLogin: (() -> Void)? // Колбэк для уведомления об успешном входе

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea() // Устанавливаем фон на весь экран
            VStack(spacing: 20) {
                Text("Вход")
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
                
                Button(action: login) {
                    Text("Войти")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.blue, .green]), startPoint: .leading, endPoint: .trailing))
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
//            .background(
//                LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
//                    .ignoresSafeArea() // Устанавливаем фон на весь экран
            
        }
    }

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = "Ошибка входа: \(error.localizedDescription)"
            } else {
                errorMessage = ""
                onLogin?() // Уведомляем об успешном входе
            }
        }
    }
}
