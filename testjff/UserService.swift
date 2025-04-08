import Firebase
import FirebaseAuth
import FirebaseFirestore
//import FirebaseFunctions

class UserService {
    static let shared = UserService() // ✅ Синглтон

    static func registerUser(email: String, password: String, role: String, companyId: String, completion: @escaping (Bool, String?) -> Void) {
        let auth = Auth.auth()
        let db = Firestore.firestore()
        

        // ✅ 1. Создаём пользователя в Firebase Authentication
        auth.createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(false, "Ошибка регистрации: \(error.localizedDescription)")
                return
            }
            
            guard let userId = authResult?.user.uid else {
                completion(false, "Не удалось получить UID пользователя")
                return
            }
            
            // ✅ 2. Добавляем пользователя в Firestore (коллекция users)
            let userRef = db.collection("users").document(userId)
            let userData: [String: Any] = [
                "email": email,
                "role": role,
                "companyId": companyId,
                "specialty": "none"
            ]
            
            userRef.setData(userData) { error in
                if let error = error {
                    completion(false, "Ошибка сохранения данных пользователя: \(error.localizedDescription)")
                    return
                }
                
                // ✅ 3. Привязываем пользователя к компании
                let companyRef = db.collection("companies").document(companyId)
                let field = role == "manager" ? "managers" : "employees"

                print("🔥 Обновляем компанию \(companyId), добавляем userId: \(userId)")

                db.collection("companies").document(companyId).updateData([
                    field: FieldValue.arrayUnion([userId])
                ]) { error in
                    if let error = error {
                        print("❌ Ошибка обновления компании: \(error.localizedDescription)")
                        completion(false, "Ошибка обновления компании: \(error.localizedDescription)")
                    } else {
                        print("✅ Сотрудник \(userId) добавлен в компанию \(companyId)!")
                        completion(true, nil)
                    }
                }
                
                
            }
        }
    }
    func fetchCompanyName(companyId: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("companies").document(companyId).getDocument { document, error in
            if let error = error {
                print("❌ Ошибка загрузки названия компании: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let document = document, document.exists {
                let companyName = document.data()?["name"] as? String ?? "Неизвестно"
                print("✅ Название компании: \(companyName)")
                completion(companyName)
            } else {
                print("❌ Компания не найдена")
                completion(nil)
            }
        }
    }

    static func createUser(email: String, password: String, companyId: String, role: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let user = authResult?.user else {
                completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь не создан"]))
                return
            }
            
            // Сохраняем данные пользователя в Firestore
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData([
                "email": email,
                "companyId": companyId,
                "role": role,
                "createdAt": FieldValue.serverTimestamp()
            ]) { error in
                completion(error)
            }
        }
    }

    // Функция для обновления смен с добавлением employeeId
    static func updateShiftsWithEmployeeId(completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        // Сначала получаем всех пользователей
        db.collection("users").getDocuments { (snapshot, error) in
            if let error = error {
                completion(error)
                return
            }
            
            // Создаем словарь [имя: id]
            var userNameToId: [String: String] = [:]
            
            // Заполняем словарь данными пользователей
            for document in snapshot?.documents ?? [] {
                if let name = document.data()["name"] as? String {
                    userNameToId[name] = document.documentID
                }
            }
            
            // Получаем все смены
            db.collection("shifts").getDocuments { (shiftsSnapshot, shiftsError) in
                if let shiftsError = shiftsError {
                    completion(shiftsError)
                    return
                }
                
                // Создаем batch для массового обновления
                let batch = db.batch()
                
                // Обновляем каждую смену
                for shiftDoc in shiftsSnapshot?.documents ?? [] {
                    if let employeeName = shiftDoc.data()["employeeName"] as? String,
                       let userId = userNameToId[employeeName] {
                        // Добавляем employeeId к документу
                        let shiftRef = db.collection("shifts").document(shiftDoc.documentID)
                        batch.updateData(["employeeId": userId], forDocument: shiftRef)
                    }
                }
                
                // Выполняем batch обновление
                batch.commit { error in
                    completion(error)
                    if let error = error {
                        print("❌ Ошибка обновления смен: \(error.localizedDescription)")
                    } else {
                        print("✅ Смены успешно обновлены")
                    }
                }
            }
        }
    }
}
