import Firebase
import FirebaseAuth

class CompanyService {
    static func createCompany(name: String, adminEmail: String, adminPassword: String, completion: @escaping (Bool, String?) -> Void) {

        // Проверяем, существует ли уже такой email
        Auth.auth().fetchSignInMethods(forEmail: adminEmail) { methods, error in
            if let error = error {
                completion(false, "Ошибка проверки email: \(error.localizedDescription)")
                return
            }

            if let methods = methods, !methods.isEmpty {
                completion(false, "Этот email уже зарегистрирован")
                return
            }

            // Если email свободен, создаем пользователя
            Auth.auth().createUser(withEmail: adminEmail, password: adminPassword) { authResult, error in
                if let error = error {
                    completion(false, "Ошибка создания администратора: \(error.localizedDescription)")
                    return
                }

                guard let adminId = authResult?.user.uid else {
                    completion(false, "Не удалось получить ID администратора")
                    return
                }

                // Создаем запись о компании
                let db = Firestore.firestore()
                let companyRef = db.collection("companies").document() // Генерируем ID компании
                let companyId = companyRef.documentID

                print("Создан администратор с ID: \(adminId), создаем компанию...")

                companyRef.setData([
                    "name": name,
                    "managers": [adminId],
                    "employees": [],
                    "createdAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("Ошибка создания компании: \(error.localizedDescription)")
                        completion(false, "Ошибка создания компании: \(error.localizedDescription)")
                    } else {
                        print("Компания успешно создана с ID: \(companyId)")

                        // Привязываем администратора к компании
                        db.collection("users").document(adminId).setData([
                            "email": adminEmail,
                            "role": "manager",
                            "companyId": companyId
                        ]) { error in
                            if let error = error {
                                print("Ошибка привязки администратора к компании: \(error.localizedDescription)")
                                completion(false, "Ошибка привязки администратора")
                            } else {
                                print("Администратор успешно привязан к компании")
                                completion(true, nil)
                            }
                        }
                    }
                }
            }
        }
    }
}
