import SwiftUI

struct RegisterCompanyView: View {
    @State private var companyName = ""
    @State private var adminEmail = ""
    @State private var adminPassword = ""
    @State private var confirmAdminPassword = ""
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea() // Устанавливаем фон на весь экран
            VStack(spacing: 20) {
                Text("Регистрация компании")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                
                TextField("Название компании", text: $companyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                TextField("Email администратора", text: $adminEmail)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                SecureField("Пароль администратора", text: $adminPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                SecureField("Подтвердите пароль администратора", text: $confirmAdminPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: registerCompany) {
                    Text("Создать компанию")
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
                        .padding()
                }
            }
            .padding()
//            .background(
//                LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
//                    .ignoresSafeArea() // Устанавливаем фон на весь экран
//            )
        }
    }
        

    func registerCompany() {
        if adminPassword != confirmAdminPassword {
            errorMessage = "Пароли не совпадают"
            return
        }

        CompanyService.createCompany(name: companyName, adminEmail: adminEmail, adminPassword: adminPassword) { success, error in
            if success {
                errorMessage = "Компания успешно создана!"
            } else {
                errorMessage = error ?? "Неизвестная ошибка"
            }
        }
    }
}
