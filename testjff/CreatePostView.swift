import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct CreatePostView: View {
    @State private var postText: String = ""
    @State private var image: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var isLoading: Bool = false
    var onPostCreated: (Post) -> Void
    var postToEdit: Post? // Передаем пост для редактирования

    var body: some View {
        VStack(spacing: 16) {
            Text("Создать публикацию")
                .font(.title)
                .bold()
                .padding(.top)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $postText)
                    .padding(8)
                    .frame(minHeight: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3))
                    )

                if postText.isEmpty {
                    Text("Введите текст")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
            }

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            }

            HStack(spacing: 16) {
                Spacer()

                Button(action: {
                    self.showImagePicker.toggle()
                }) {
                    Image(systemName: "paperclip")
                        .font(.title2)
                        .padding(10)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .disabled(isLoading)

                Button(action: {
                    self.createPost()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                }
                .disabled(isLoading || postText.isEmpty)
            }
            .padding(.trailing)

            Spacer()
        }
        .padding()
        .navigationTitle(postToEdit == nil ? "Создать пост" : "Редактировать пост")
        .navigationBarItems(leading: Button("Отмена") {
            self.dismiss()
        })
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: self.$image)
        }
        .onAppear {
            if let postToEdit = postToEdit {
                // Заполняем данные для редактирования
                self.postText = postToEdit.text
                // Можем добавить изображение, если оно есть
            }
        }
    }

    func createPost() {
        isLoading = true
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        var postData: [String: Any] = [
            "text": postText,
            "authorId": userId,
            "timestamp": FieldValue.serverTimestamp()
        ]

        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            let storage = Storage.storage()
            let imageRef = storage.reference().child("postImages/\(UUID().uuidString).jpg")

            imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                    isLoading = false
                    return
                }

                imageRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ Ошибка получения URL изображения: \(error.localizedDescription)")
                        isLoading = false
                        return
                    }

                    if let url = url {
                        postData["imageUrl"] = url.absoluteString
                        self.savePostData(postData)
                    }
                }
            }
        } else {
            self.savePostData(postData)
        }
    }

    func savePostData(_ postData: [String: Any]) {
        let db = Firestore.firestore()
        if let postToEdit = postToEdit {
            db.collection("posts").document(postToEdit.id).updateData(postData) { error in
                if let error = error {
                    print("❌ Ошибка обновления поста: \(error.localizedDescription)")
                } else {
                    print("✅ Пост успешно обновлен")
                    self.dismiss()
                }
                isLoading = false
            }
        } else {
            db.collection("posts").addDocument(data: postData) { error in
                if let error = error {
                    print("❌ Ошибка создания поста: \(error.localizedDescription)")
                } else {
                    print("✅ Пост успешно создан")
                    self.dismiss()
                }
                isLoading = false
            }
        }
    }

    func dismiss() {
        UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.dismiss(animated: true, completion: nil)
    }
}

