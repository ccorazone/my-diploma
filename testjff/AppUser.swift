import Foundation

struct AppUser: Identifiable {
    var id: String
    var name: String = "Неизвестно" // Дополнительное поле
    var email: String
    var role: String
    var specialty: String = "Не указано" // Дополнительное поле
}
