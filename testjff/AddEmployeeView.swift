/*import SwiftUI
import Firebase
import FirebaseAuth


struct AddEmployeeView: View {
    @State private var email = ""
    @State private var errorMessage = ""
    var onEmployeeAdded: () -> Void // Колбэк для обновления списка сотрудников

    var body: some View {
        VStack(spacing: 20) {
            Text("Добавить сотрудника")
                .font(.largeTitle)
                .padding()

            TextField("Email сотрудника", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .padding(.horizontal)

            Button(action: addEmployee) {
                Text("Добавить")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    func addEmployee() {
        let db = Firestore.firestore()
        let newEmployee = db.collection("users").document()
        let companyId = Auth.auth().currentUser?.uid ?? ""

        newEmployee.setData([
            "email": email,
            "role": "employee",
            "companyId": companyId
        ]) { error in
            if let error = error {
                errorMessage = "Ошибка: \(error.localizedDescription)"
            } else {
                onEmployeeAdded()
            }
        }
    }
}
*/
