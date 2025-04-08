import SwiftUI
import FirebaseAuth

struct ChatView: View {
    var employee: AppUser
    @State private var messages: [Message] = []
    @State private var textMessage: String = ""

    var body: some View {
        VStack {
            // ✅ Заголовок с именем/email сотрудника
            VStack {
                Text(employee.email)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 5)

            // ✅ Список сообщений
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { message in
                        HStack {
                            if message.senderId == Auth.auth().currentUser?.uid {
                                Spacer()
                                Text(message.text)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                                    .shadow(radius: 2)
                            } else {
                                Text(message.text)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.black)
                                    .cornerRadius(15)
                                    .shadow(radius: 2)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 5)

            // ✅ Поле ввода и кнопка отправки
            HStack {
                TextField("Введите сообщение...", text: $textMessage)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .onAppear {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ Ошибка: Пользователь не авторизован")
                return
            }

            let adminId = currentUserId
            let chatId = ChatService.shared.getChatId(adminId: adminId, employeeId: employee.id)

            print("📡 Загружаем сообщения для чата с \(employee.email)")
            print("📌 chatId: \(chatId)")

            ChatService.shared.observeMessages(adminId: adminId, employeeId: employee.id) { messages in
                DispatchQueue.main.async {
                    print("✅ Сообщения загружены: \(messages.count)")
                    self.messages = messages
                }
            }
        }


    }

    func sendMessage() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ Ошибка: Пользователь не авторизован")
                return
            }
            ChatService.shared.sendMessage(adminId: currentUserId, employeeId: employee.id, text: textMessage) { success, error in
                if success {
                    textMessage = "" // Очистка поля
                } else {
                    print("❌ Ошибка: \(error ?? "Неизвестная ошибка")")
                }
            }
    }
}
    
