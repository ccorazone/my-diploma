import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EmployeeHomeView: View {
    @State private var userName: String = "Сотрудник"
    @State private var posts: [Post] = [] // Список постов
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Добро пожаловать, \(userName)!")
                .font(.largeTitle)
                .padding()

            // Display posts
            if !posts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(posts.sorted(by: { $0.timestamp > $1.timestamp })) { post in
                            PostCardView(
                                post: post,
                                onDelete: {
                                    deletePost(post)
                                },
                                onEdit: {
                                    editPost(post: post)
                                },
                                onReact: { post, isAdding in
                                        reactToPost(post, isAdding: isAdding)
                                },
                                isEmployeeMode: true // 👈 передаем флаг
                            )
                            .frame(width: UIScreen.main.bounds.width * 0.85)

                        }
                    }
                    .padding()
                }
            } else {
                Text("Посты не найдены.")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .onAppear {
            fetchUserName()
            fetchPosts() // Fetch posts when the view appears
        }
    }

    // Function to fetch the user's name from Firestore
    func fetchUserName() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Ошибка: Пользователь не авторизован")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                if let name = document.data()?["name"] as? String {
                    DispatchQueue.main.async {
                        self.userName = name
                    }
                }
            } else {
                print("❌ Ошибка загрузки имени пользователя: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }

    // Fetching posts from Firestore
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
                    reactions: data["reactions"] as? [String: Int] ?? [:]
                )
            }
        }
    }

    // Reaction function (like, for example)
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
                    DispatchQueue.main.async {
                        if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                            self.posts[index].reactions[userId] = 1
                        }
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
                    DispatchQueue.main.async {
                        if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                            self.posts[index].reactions.removeValue(forKey: userId)
                        }
                    }
                }
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
        // Логика редактирования
        print("Редактирование поста с ID: \(post.id)")
    }
}


