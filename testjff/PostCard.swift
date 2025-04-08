import Foundation

struct Post: Identifiable {
    var id: String
    var text: String
    var imageUrl: String?
    var timestamp: Date
    var reactions: [String: Int] // Словарь с реакциями, где ключ - ID пользователя, значение - количество реакций (например, лайков)
}
