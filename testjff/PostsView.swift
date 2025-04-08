import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct PostsView: View {
    @State private var posts: [Post] = []

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(posts.sorted(by: { $0.timestamp > $1.timestamp })) { post in
                        PostCardView(
                            post: post,
                            onDelete: {
                                deletePost(post) // Передаем post в функцию deletePost
                            },
                            onEdit: {
                                editPost(post: post) // Передаем post в функцию editPost с явной меткой
                            },
                            onReact: { post, isAdding in
                                    reactToPost(post, isAdding: isAdding) //
                                }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Посты")
            .onAppear(perform: fetchPosts)
        }
    }

    // Функция для получения постов
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
                    reactions: data["reactions"] as? [String: Int] ?? [:] // Загрузка реакций
                )
            }
        }
    }

    // Функция для реакции на пост (например, лайк)
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
