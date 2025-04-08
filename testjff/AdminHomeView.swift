import SwiftUI
import FirebaseAuth
import Firebase

struct AdminHomeView: View {
    @State private var userName: String = "Администратор"
    @State private var posts: [Post] = [] // Список постов
    @State private var showCreatePostView = false
    @State private var selectedPost: Post? = nil // Для редактирования выбранного поста
    @State private var isEditingPost = false // Флаг для редактирования поста
    @State private var showDeleteConfirmation = false // Флаг для подтверждения удаления поста
    @State private var postToDelete: Post? = nil // Пост для удаления

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Добро пожаловать,")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text(userName)
                        .font(.largeTitle)
                        .bold()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Button(action: {
                    self.isEditingPost = false // Устанавливаем, что мы создаем новый пост
                    self.selectedPost = nil  // Сбрасываем выбранный пост
                    self.showCreatePostView.toggle()
                }) {
                    Label("Создать пост", systemImage: "plus.circle.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)

                // Отображение постов с горизонтальной прокруткой
                if !posts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(posts.sorted(by: { $0.timestamp > $1.timestamp })) { post in
                                // Передаем обработчик реакции (например, лайк)
                                PostCardView(
                                    post: post,
                                    onDelete: { confirmDeletePost(post: post) }, // Передаем post в confirmDeletePost
                                    onEdit: { editPost(post: post) }, // Передаем post в editPost
                                    onReact: { post, isAdding in
                                            reactToPost(post, isAdding: isAdding) //
                                        } // Передаем post в reactToPost
                                )
                                .frame(width: UIScreen.main.bounds.width * 0.85)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 300) // Устанавливаем высоту горизонтального списка
                } else {
                    Text("Посты не найдены.")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .sheet(isPresented: $showCreatePostView) {
                CreatePostView(onPostCreated: { newPost in
                    if isEditingPost, let selectedPost = self.selectedPost {
                        // Редактируем существующий пост
                        self.updatePost(selectedPost, with: newPost)
                    } else {
                        // Добавляем новый пост
                        self.posts.insert(newPost, at: 0)
                    }
                }, postToEdit: selectedPost) // Передаем пост для редактирования, если есть
            }
            .onAppear {
                fetchUserName()
                fetchPosts() // Загрузка постов при первоначальном открытии экрана
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Удалить пост?"),
                    message: Text("Вы уверены, что хотите удалить этот пост?"),
                    primaryButton: .destructive(Text("Удалить")) {
                        if let postToDelete = postToDelete {
                            deletePost(postToDelete)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // Обработчик реакции (например, лайк)
    func reactToPost(_ post: Post, isAdding: Bool) {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let postRef = db.collection("posts").document(post.id)

        if isAdding {
            postRef.updateData([
                "reactions.\(userId)": 1
            ]) { error in
                if let error = error {
                    print("❌ Ошибка при добавлении реакции: \(error.localizedDescription)")
                } else {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index].reactions[userId] = 1
                    }
                }
            }
        } else {
            postRef.updateData([
                "reactions.\(userId)": FieldValue.delete()
            ]) { error in
                if let error = error {
                    print("❌ Ошибка при удалении реакции: \(error.localizedDescription)")
                } else {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index].reactions.removeValue(forKey: userId)
                    }
                }
            }
        }
    }


    // Обновление поста
    func updatePost(_ oldPost: Post, with newPost: Post) {
        let db = Firestore.firestore()

        db.collection("posts").document(oldPost.id).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка при получении поста для обновления: \(error.localizedDescription)")
                return
            }

            if document?.exists == true {
                // Обновление поста в Firestore
                db.collection("posts").document(oldPost.id).updateData([
                    "text": newPost.text,
                    "imageUrl": newPost.imageUrl ?? "",
                    "timestamp": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("❌ Ошибка обновления поста: \(error.localizedDescription)")
                    } else {
                        print("✅ Пост успешно обновлен")
                        
                        // Обновляем пост в локальном массиве
                        if let index = self.posts.firstIndex(where: { $0.id == oldPost.id }) {
                            self.posts[index] = newPost // Заменяем старый пост на новый
                        }
                    }
                }
            } else {
                print("❌ Документ не найден для обновления")
            }
        }
    }

    // Загрузка имени пользователя
    func fetchUserName() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists,
               let name = document.data()?["name"] as? String {
                DispatchQueue.main.async {
                    self.userName = name
                }
            } else {
                print("❌ Ошибка загрузки имени пользователя: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }

    // Загрузка постов
    func fetchPosts() {
        let db = Firestore.firestore()
        db.collection("posts").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Ошибка загрузки постов: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("❌ No documents found.")
                return
            }

            self.posts = documents.map { doc in
                let data = doc.data()
                return Post(
                    id: doc.documentID,
                    text: data["text"] as? String ?? "",
                    imageUrl: data["imageUrl"] as? String,
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    reactions: data["reactions"] as? [String: Int] ?? [:] // Загружаем реакции
                )
            }
        }
    }

    // Удаление поста
    func deletePost(_ post: Post) {
        let db = Firestore.firestore()
        db.collection("posts").document(post.id).delete { error in
            if let error = error {
                print("❌ Ошибка удаления поста: \(error.localizedDescription)")
            } else {
                // Удаляем пост из локального списка
                self.posts.removeAll { $0.id == post.id }
                print("✅ Пост удален успешно")
            }
        }
    }

    // Редактирование поста
    func editPost(post: Post) {
        self.selectedPost = post
        self.isEditingPost = true // Устанавливаем флаг редактирования
        self.showCreatePostView.toggle() // Переходим на экран редактирования
    }

    // Подтверждение удаления
    func confirmDeletePost(post: Post) {
        self.postToDelete = post
        self.showDeleteConfirmation.toggle() // Показать alert
    }
}
