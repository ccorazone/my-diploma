import SwiftUI
import Firebase
import FirebaseAuth

struct DayCell: View {
    let date: Date
    @Binding var selectedDate: Date?
    let shifts: [WorkShift]
    let isCurrentMonth: Bool
    
    private var isSelected: Bool {
        guard let selectedDate = selectedDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isCurrentMonth ? (isSelected ? .white : .primary) : .gray)
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Circle())
            
            if !shifts.isEmpty {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 45)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
