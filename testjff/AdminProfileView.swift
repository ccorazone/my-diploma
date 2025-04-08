import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct AdminProfileView: View {
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var specialty: String = ""
    @State private var email: String = Auth.auth().currentUser?.email ?? ""
    @State private var companyName: String = "Неизвестно"
    @State private var companyId: String = ""
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
    @State private var showChangePasswordScreen = false

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
                            CustomTextField(icon: "briefcase", placeholder: "Должность", text: $specialty)
                        } else {
                            ProfileInfoRow(icon: "person", title: "Имя", value: name)
                            ProfileInfoRow(icon: "phone", title: "Телефон", value: phone)
                            ProfileInfoRow(icon: "briefcase", title: "Должность", value: specialty)
                        }
                        ProfileInfoRow(icon: "building.2", title: "Компания", value: companyName)
                        ProfileInfoRow(icon: "number", title: "ID компании", value: companyId)
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
                .padding(.horizontal)
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
            fetchUserData()
        }
    }

    func saveProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "name": name,
            "phone": phone,
            "specialty": specialty,
            "notificationsEnabled": notificationsEnabled
        ]) { error in
            if let error = error {
                print("❌ Ошибка сохранения профиля: \(error.localizedDescription)")
            } else {
                print("✅ Профиль обновлен!")
                DispatchQueue.main.async {
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

    func fetchUserData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: пользователь не аутентифицирован")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                self.name = data?["name"] as? String ?? ""
                self.phone = data?["phone"] as? String ?? ""
                self.specialty = data?["specialty"] as? String ?? ""
                self.companyId = data?["companyId"] as? String ?? "Неизвестно"
                self.notificationsEnabled = data?["notificationsEnabled"] as? Bool ?? true
                
                if let companyId = data?["companyId"] as? String {
                    UserService.shared.fetchCompanyName(companyId: companyId) { name in
                        DispatchQueue.main.async {
                            self.companyName = name ?? "Неизвестно"
                        }
                    }
                }
                
                // Fetch avatar URL
                if let avatarUrl = data?["avatarUrl"] as? String, let url = URL(string: avatarUrl) {
                    downloadImage(from: url) { image in
                        DispatchQueue.main.async {
                            if let image = image {
                                self.avatarImage = Image(uiImage: image)
                            }
                        }
                    }
                }
            } else {
                print("❌ Ошибка загрузки данных пользователя")
            }
            isLoading = false
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
            if let error = error {
                print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                return
            }

            storageRef.downloadURL { url, error in
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
                    if let error = error {
                        print("❌ Ошибка сохранения URL изображения: \(error.localizedDescription)")
                    } else {
                        print("✅ URL изображения успешно сохранен в Firestore")
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


struct AdminProfileView_Previews: PreviewProvider {
    static var previews: some View {
        AdminProfileView()
            .environmentObject(AuthState())
    }
}
