import SwiftUI
import Firebase
import FirebaseAuth

struct EmployeeDashboardView: View {
    @EnvironmentObject var authState: AuthState // Подключение AuthState
    @State private var selectedTab: Int = 0 // Для переключения между вкладками

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                EmployeeHomeView() // Главная страница сотрудника
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Главная")
                    }
                    .tag(0)

                EmployeeScheduleView() // График смен
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Смены")
                    }
                    .tag(1)

                EmployeeProfileView() // Настройки профиля
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Профиль")
                    }
                    .tag(2)
            }
            .navigationBarTitle(titleForTab(selectedTab), displayMode: .inline)
        }
    }

    // Возвращает заголовок для каждой вкладки
    func titleForTab(_ tab: Int) -> String {
        switch tab {
        case 0:
            return "Главная"
        case 1:
            return "Смены"
        case 2:
            return "Профиль"
        default:
            return ""
        }
    }
}
