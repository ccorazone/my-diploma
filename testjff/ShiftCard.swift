import SwiftUI
import Firebase

struct ShiftCard: View {
    let shift: WorkShift
    var showActions: Bool = false
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    
    private var breakStartTime: Date {
        if let breakStartTime = shift.breakStartTime {
            return breakStartTime.dateValue()
        }
        // Если нет времени начала перерыва в БД, используем старую логику
        return shift.startTime.dateValue().addingTimeInterval(4 * 3600)
    }
    
    private var breakEndTime: Date {
        if let breakEndTime = shift.breakEndTime {
            return breakEndTime.dateValue()
        }
        // Если нет времени конца перерыва в БД, используем старую логику
        return breakStartTime.addingTimeInterval(TimeInterval(shift.breakTime ?? 0) * 60)
    }
    
    private var shiftDuration: Double {
        let duration = shift.endTime.dateValue().timeIntervalSince(shift.startTime.dateValue())
        let hours = duration / 3600.0
        if let breakTime = shift.breakTime {
            return hours - (Double(breakTime) / 60.0)
        }
        return hours
    }
    
    private func formatTime(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp.dateValue())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Преобразуем строку даты в объект Date
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        
        // Форматируем дату для отображения
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMMM"
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Зона и специальность
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.zone)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(shift.specialty)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
                
                if showActions {
                    HStack(spacing: 12) {
                        Button(action: { onEdit?() }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        }
                        
                        Button(action: { onDelete?() }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                    }
                } else {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                }
            }
            .frame(height: 40)
            
            Divider()
            
            // Дата и время смены
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text(formatDate(shift.date))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Время смены:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(formatTime(shift.startTime)) - \(formatTime(shift.endTime))")
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Spacer()
                        Text("\(String(format: "%.1f", shiftDuration)) часов")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .frame(height: 50)
            
            // Перерыв
            if let breakTime = shift.breakTime, breakTime > 0 {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "cup.and.saucer")
                            .foregroundColor(.orange)
                        Text("Перерыв:")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(formatTime(breakStartTime)) - \(formatTime(breakEndTime))")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    
                    Text("\(breakTime) минут")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 60)
            } else {
                Spacer()
                    .frame(height: 60)
            }
        }
        .frame(width: 300, height: 180)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}
