import Foundation

struct Habit: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var completedDates: Set<String> = []
}

struct PlannerTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var dateKey: String
    var isDone = false
}

struct PlannerData: Codable {
    var habits: [Habit] = [
        Habit(title: "Вставать в 6 утра"),
        Habit(title: "Читать 20 минут"),
        Habit(title: "Аффирмации и цели")
    ]
    var tasks: [PlannerTask] = []
    var note = ""
}

enum PlannerDate {
    static let calendar = Calendar.current
    static let keyFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "EEEE"; return f
    }()
    static let fullFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "d MMMM"; return f
    }()
    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }
}

