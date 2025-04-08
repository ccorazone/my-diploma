import SwiftUI

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    var shiftDays: Set<Int>

    let calendar = Calendar.current
    let currentMonth: Date

    init(selectedDate: Binding<Date>, shiftDays: Set<Int>) {
        self._selectedDate = selectedDate
        self.shiftDays = shiftDays
        self.currentMonth = selectedDate.wrappedValue
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                Spacer()
                Text(monthAndYear())
                    .font(.headline)
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding()

            let daysInMonth = daysOfMonth()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(daysInMonth, id: \.self) { day in
                    if let day = day {
                        Button(action: { selectedDate = getDate(day: day) }) {
                            Text("\(day)")
                                .frame(width: 30, height: 30)
                                .background(day == calendar.component(.day, from: selectedDate) ? Color.blue : (shiftDays.contains(day) ? Color.green : Color.clear))
                                .foregroundColor(day == calendar.component(.day, from: selectedDate) ? .white : .black)
                                .clipShape(Circle())
                        }
                    } else {
                        Text("")
                            .frame(width: 30, height: 30)
                    }
                }
            }
        }
    }

    func monthAndYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    func daysOfMonth() -> [Int?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstWeekday = calendar.component(.weekday, from: calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!)
        return Array(repeating: nil, count: firstWeekday - 1) + Array(range)
    }

    func getDate(day: Int) -> Date {
        return calendar.date(from: DateComponents(year: calendar.component(.year, from: currentMonth), month: calendar.component(.month, from: currentMonth), day: day))!
    }

    func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            selectedDate = newMonth
        }
    }
}
