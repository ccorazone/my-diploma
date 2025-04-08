import Firebase
import FirebaseAuth

class ChatService {
    static let shared = ChatService() // Синглтон для использования везде
    private let db = Firestore.firestore()

    /// Получаем `chatId` по `adminId` и `employeeId`
    func getChatId(adminId: String, employeeId: String) -> String {
        return adminId < employeeId ? "\(adminId)_\(employeeId)" : "\(employeeId)_\(adminId)"
    }

    /// Отправка сообщения (автоматически создаёт чат, если его нет)
    func sendMessage(adminId: String, employeeId: String, text: String, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false, "Пользователь не авторизован")
            return
        }

        let chatId = getChatId(adminId: adminId, employeeId: employeeId)
        let chatRef = db.collection("chats").document(chatId)
        let messageRef = chatRef.collection("messages").document()

        let receiverId = (currentUserId == adminId) ? employeeId : adminId

        let messageData: [String: Any] = [
            "senderId": currentUserId,
            "receiverId": receiverId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]

        // 🔹 Создаём чат (если его нет)
        chatRef.setData([
            "lastMessage": text,
            "timestamp": FieldValue.serverTimestamp(),
            "participants": [adminId, employeeId] // Список участников чата
        ], merge: true)

        // 🔹 Добавляем сообщение в подколлекцию `messages`
        messageRef.setData(messageData) { error in
            if let error = error {
                completion(false, "Ошибка отправки сообщения: \(error.localizedDescription)")
            } else {
                completion(true, nil)
            }
        }
    }

    /// Получение сообщений (в реальном времени)
    func observeMessages(adminId: String, employeeId: String, completion: @escaping ([Message]) -> Void) {
        let chatId = getChatId(adminId: adminId, employeeId: employeeId)

        print("👀 Начинаем слушать сообщения в чате: \(chatId)")

        db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Ошибка загрузки сообщений: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ Нет сообщений в чате \(chatId)")
                    return
                }

                let messages = documents.compactMap { doc -> Message? in
                    let data = doc.data()
                    return Message(
                        id: doc.documentID,
                        senderId: data["senderId"] as? String ?? "",
                        receiverId: data["receiverId"] as? String ?? "",
                        text: data["text"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                print("✅ Загружено сообщений: \(messages.count)")
                messages.forEach { print("📩 \( $0.text ) от \( $0.senderId )") }

                DispatchQueue.main.async {
                    completion(messages)
                }
            }
    }

}

// Модель сообщения
struct Message: Identifiable {
    var id: String
    var senderId: String
    var receiverId: String
    var text: String
    var timestamp: Date
}
