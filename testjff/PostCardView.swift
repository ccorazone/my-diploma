import SwiftUI
import Firebase
import FirebaseAuth
import SDWebImageSwiftUI

struct PostCardView: View {
    let post: Post
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onReact: (Post, Bool) -> Void // 👈 Передаём флаг: добавляем или убираем
    var isEmployeeMode: Bool = false

    @State private var isLoading: Bool = true
    @State private var localReactions: [String: Int] = [:]
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }

    var hasReacted: Bool {
        userId != nil && localReactions[userId!] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Картинка
            ZStack {
                // Проверяем, если URL изображения доступен, то загружаем изображение
                if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                    WebImage(url: url)
                        .resizable() // Делаем изображение растягиваемым
                        .onSuccess { _, _, _ in
                            DispatchQueue.main.async {
                                isLoading = false
                            }
                        }
                        .onFailure { _ in
                            DispatchQueue.main.async {
                                isLoading = false
                            }
                        }
                        .indicator(.activity) // Добавляем индикатор загрузки (кружок загрузки)
                        .scaledToFill() // Растягиваем изображение, чтобы оно заполнило доступное пространство
                        .frame(maxWidth: .infinity, maxHeight: 200) // Устанавливаем максимальные размеры для изображения
                        .clipped() // Обрезаем изображение, если оно выходит за пределы
                        .cornerRadius(16) // Скругляем углы изображения
                }
                
                // Если изображение загружается, показываем индикатор загрузки
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }



            // Текст и дата
            Text(post.text)
                .font(.body)
                .foregroundColor(.primary)
            Text(post.timestamp, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)

            // Реакции
            HStack {
                Button(action: {
                    guard let uid = userId else { return }

                    var updatedPost = post
                    if hasReacted {
                        updatedPost.reactions.removeValue(forKey: uid)
                        localReactions.removeValue(forKey: uid)
                        onReact(updatedPost, false)
                    } else {
                        updatedPost.reactions[uid] = 1
                        localReactions[uid] = 1
                        onReact(updatedPost, true)
                    }
                }) {
                    Text(hasReacted ? "Убрать лайк" : "Лайк")
                        .foregroundColor(hasReacted ? .red : .blue)
                }
                .padding(.trailing)

                Text("Лайков: \(localReactions.values.reduce(0, +))")
                    .font(.subheadline)

                Spacer()

                if !isEmployeeMode {
                    Button(action: onEdit) {
                        Text("Редактировать")
                            .foregroundColor(.blue)
                    }
                    Spacer()

                    Button(action: onDelete) {
                        Text("Удалить")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
        .onAppear {
            self.localReactions = post.reactions
        }
    }
}



