import SwiftUI
import Firebase
import FirebaseAuth

struct AdminDashboardView: View {
    @EnvironmentObject var authState: AuthState // Подключение AuthState
    @State private var selectedTab: Int = 0 // Для переключения между вкладками

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                AdminHomeView() // Главная страница
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Главная")
                    }
                    .tag(0)

                EmployeeListView(selectedTab: selectedTab) // Список сотрудников
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("Сотрудники")
                    }
                    .tag(1)

                 
                ShiftManagementView()
                        .tabItem {
                            Image(systemName: "calendar.badge.clock")
                            Text("Смены")
                        }
                        .tag(2)
                

                AdminProfileView() // Настройки профиля
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Настройки")
                    }
                    .tag(3)
            }
            .navigationBarTitle(titleForTab(selectedTab), displayMode: .inline)
            /*/.navigationBarItems(trailing: Button(action: logout) {
                Image(systemName: "arrow.right.square")
                    .foregroundColor(.red)
            })*/
        }
    }

    // Название для заголовка
    func titleForTab(_ tab: Int) -> String {
        switch tab {
        case 0:
            return "Главная"
        case 1:
            return "Сотрудники"
        case 2:
            return "Смены"
        case 3:
            return "Настройки"
        default:
            return ""
        }
    }

    // Логика выхода
    /*func logout() {
        do {
            try Auth.auth().signOut()
            authState.isLoggedIn = false
            authState.userRole = nil
        } catch let error {
            print("Ошибка выхода: \(error.localizedDescription)")
        }
    }*/
}
