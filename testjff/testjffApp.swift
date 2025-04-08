import SwiftUI
import Firebase

@main
struct YourAppName: App {
    @StateObject private var authState = AuthState() // Глобальное состояние

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState) // Передаем состояние авторизации
        }
    }
}
