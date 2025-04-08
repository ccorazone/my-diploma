import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct EmployeeProfileView: View {
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = Auth.auth().currentUser?.email ?? ""
    @State private var birthDate = Date()
    @State private var notificationsEnabled: Bool = true
    @State private var showLogoutAlert = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert = false
    @State private var avatarImage: Image? = nil
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var isEditing = false
    @State private var isLoading = true
    @EnvironmentObject var authState: AuthState
    @State private var employeeData: [String: Any] = [:]
    @State private var companyName: String = ""
    @State private var showChangePasswordScreen = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Аватар и основная информация
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)

                        if let avatar = avatarImage {
                            avatar
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.blue)
                                .frame(width: 110, height: 110)
                        }

                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 120, height: 120)
                    }
                    .onTapGesture {
                        showImagePicker = true
                    }

                    Text(name.isEmpty ? "Добавьте имя" : name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical)

                // Основная информация
                GroupBox(label: HStack {
                    Label("Личная информация", systemImage: "person.text.rectangle")
                    Spacer()
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 15) {
                        if isEditing {
                            CustomTextField(icon: "person", placeholder: "Имя", text: $name)
                            CustomTextField(icon: "phone", placeholder: "Телефон", text: $phone)
                            DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        } else {
                            ProfileInfoRow(icon: "person", title: "Имя", value: name)
                            ProfileInfoRow(icon: "phone", title: "Телефон", value: phone)
                            ProfileInfoRow(icon: "calendar", title: "Дата рождения", value: dateFormatter.string(from: birthDate))
                        }
                        ProfileInfoRow(icon: "building.2", title: "Компания", value: companyName)
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal)

                // Настройки
                GroupBox(label: Label("Настройки", systemImage: "gear")) {
                    VStack(spacing: 15) {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Уведомления", systemImage: "bell.fill")
                                .foregroundColor(.primary)
                        }

                        Divider()

                        Button(action: { showChangePasswordScreen = true }) {
                            Label("Сменить пароль", systemImage: "lock.rotation")
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .sheet(isPresented: $showChangePasswordScreen) {
                            ChangePasswordView(showSuccessAlert: $showSuccessAlert, showErrorAlert: $showErrorAlert, errorMessage: $errorMessage)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)

                // Кнопки действий
                if isEditing {
                    Button(action: {
                        saveProfile()
                        isEditing = false
                    }) {
                        Text("Сохранить изменения")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Button(action: { showLogoutAlert = true }) {
                    Text("Выйти из аккаунта")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Успешно!", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Изменения успешно сохранены")
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Ошибка"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Выход"),
                message: Text("Вы уверены, что хотите выйти?"),
                primaryButton: .destructive(Text("Выйти")) {
                    logout()
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
            ImagePicker(image: $inputImage)
        }
        .onAppear {
            fetchEmployeeData()
        }
    }

    func saveProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "name": name,
            "phone": phone,
            "birthDate": Timestamp(date: birthDate),
            "notificationsEnabled": notificationsEnabled
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Ошибка сохранения профиля: \(error.localizedDescription)")
                } else {
                    print("✅ Профиль обновлен!")
                    showSuccessAlert = true
                }
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            authState.isLoggedIn = false
            authState.userRole = nil
        } catch let error {
            print("❌ Ошибка выхода: \(error.localizedDescription)")
        }
    }

    private func fetchEmployeeData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()

        // Получаем данные пользователя
        db.collection("users").document(userId).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ошибка при загрузке данных пользователя: \(error.localizedDescription)")
                    return
                }

                if let data = document?.data() {
                    self.name = data["name"] as? String ?? ""
                    self.phone = data["phone"] as? String ?? ""
                    if let birthTimestamp = data["birthDate"] as? Timestamp {
                        self.birthDate = birthTimestamp.dateValue()
                    }
                    self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true

                    // Получаем данные компании
                    if let companyId = data["companyId"] as? String {
                        UserService.shared.fetchCompanyName(companyId: companyId) { companyName in
                            DispatchQueue.main.async {
                                self.companyName = companyName ?? "Неизвестно"
                            }
                        }
                    }

                    // Fetch avatar URL
                    if let avatarUrl = data["avatarUrl"] as? String, let url = URL(string: avatarUrl) {
                        downloadImage(from: url) { image in
                            DispatchQueue.main.async {
                                if let image = image {
                                    self.avatarImage = Image(uiImage: image)
                                }
                            }
                        }
                    }
                }

                isLoading = false
            }
        }
    }

    func loadImage() {
        guard let inputImage = inputImage else { return }
        avatarImage = Image(uiImage: inputImage)
        uploadImage(inputImage)
    }

    func uploadImage(_ image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let storageRef = Storage.storage().reference().child("avatars/\(userId).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.75) else { return }

        storageRef.putData(imageData, metadata: nil) { metadata, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                    return
                }

                storageRef.downloadURL { url, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Ошибка получения URL изображения: \(error.localizedDescription)")
                            return
                        }

                        guard let url = url else { return }
                        print("✅ URL изображения: \(url.absoluteString)")
                        let db = Firestore.firestore()
                        db.collection("users").document(userId).updateData([
                            "avatarUrl": url.absoluteString
                        ]) { error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    print("❌ Ошибка сохранения URL изображения: \(error.localizedDescription)")
                                } else {
                                    print("✅ URL изображения успешно сохранен в Firestore")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
    }
}

// Кастомное текстовое поле
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            TextField(placeholder, text: $text)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

struct ChangePasswordView: View {
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @Binding var showSuccessAlert: Bool
    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String

    var body: some View {
        NavigationView {
            VStack {
                SecureField("Старый пароль", text: $oldPassword)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.bottom, 10)

                SecureField("Новый пароль", text: $newPassword)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.bottom, 10)

                SecureField("Повторите новый пароль", text: $confirmPassword)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.bottom, 20)

                Button(action: {
                    changePassword()
                }) {
                    Text("Сменить пароль")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Изменение пароля")
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Ошибка"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("Успешно!"),
                    message: Text("Пароль успешно изменен"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    func changePassword() {
        print("Проверка старого пароля")
        guard !oldPassword.isEmpty else {
            DispatchQueue.main.async {
                errorMessage = "Старый пароль не может быть пустым!"
                showErrorAlert = true
            }
            return
        }

        print("Проверка нового пароля")
        guard !newPassword.isEmpty else {
            DispatchQueue.main.async {
                errorMessage = "Новый пароль не может быть пустым!"
                showErrorAlert = true
            }
            return
        }

        print("Проверка подтверждения пароля")
        guard !confirmPassword.isEmpty else {
            DispatchQueue.main.async {
                errorMessage = "Подтверждение пароля не может быть пустым!"
                showErrorAlert = true
            }
            return
        }

        print("Проверка совпадения нового и подтвержденного пароля")
        guard newPassword == confirmPassword else {
            DispatchQueue.main.async {
                errorMessage = "Новые пароли не совпадают!"
                showErrorAlert = true
            }
            return
        }

        print("Проверка длины нового пароля")
        guard newPassword.count >= 8 else {
            DispatchQueue.main.async {
                errorMessage = "Пароль должен содержать не менее 8 символов"
                showErrorAlert = true
            }
            return
        }

        print("Проверка наличия букв и цифр в новом пароле")
        let passwordRegex = "^(?=.*[a-zA-Z])(?=.*[0-9]).{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        guard passwordPredicate.evaluate(with: newPassword) else {
            DispatchQueue.main.async {
                errorMessage = "Пароль должен содержать буквы и цифры"
                showErrorAlert = true
            }
            return
        }

        let user = Auth.auth().currentUser
        let credential = EmailAuthProvider.credential(withEmail: user?.email ?? "", password: oldPassword)

        user?.reauthenticate(with: credential) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("Ошибка повторной аутентификации: \(error.localizedDescription)")
                    errorMessage = "Ошибка повторной аутентификации: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            } else {
                user?.updatePassword(to: newPassword) { error in
                    if let error = error {
                        DispatchQueue.main.async {
                            print("Ошибка смены пароля: \(error.localizedDescription)")
                            errorMessage = "Ошибка смены пароля: \(error.localizedDescription)"
                            showErrorAlert = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            print("✅ Пароль успешно изменен!")
                            oldPassword = ""
                            newPassword = ""
                            confirmPassword = ""
                            showSuccessAlert = true
                        }
                    }
                }
            }
        }
    }
}

struct EmployeeProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EmployeeProfileView()
            .environmentObject(AuthState())
    }
}
