import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userRole: String? = nil
    @Published var companyId: String? // ← Добавляем companyId

        func fetchCompanyId() {
            guard let user = Auth.auth().currentUser else { return }
            let db = Firestore.firestore()
            
            db.collection("users").document(user.uid).getDocument { document, error in
                if let data = document?.data(), let companyId = data["companyId"] as? String {
                    DispatchQueue.main.async {
                        self.companyId = companyId
                    }
                }
            }
        }
}
