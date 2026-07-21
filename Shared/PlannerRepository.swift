import Foundation
import Combine
import WidgetKit

@MainActor final class PlannerRepository: ObservableObject {
    static let suite = "group.ru.alina.planner"
    static let storageKey = "planner.data.v1"
    @Published var data: PlannerData { didSet { save() } }

    init() {
        if let raw = UserDefaults(suiteName: Self.suite)?.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(PlannerData.self, from: raw) { data = decoded }
        else { data = PlannerData() }
    }

    func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        UserDefaults(suiteName: Self.suite)?.set(raw, forKey: Self.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func tasks(on date: Date) -> [PlannerTask] { data.tasks.filter { $0.dateKey == PlannerDate.key(date) } }
    func toggleTask(_ task: PlannerTask) {
        guard let i = data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        data.tasks[i].isDone.toggle()
    }
    func addTask(_ title: String, on date: Date) { data.tasks.append(.init(title: title, dateKey: PlannerDate.key(date))) }
    func deleteTask(_ task: PlannerTask) { data.tasks.removeAll { $0.id == task.id } }
    func toggleHabit(_ habit: Habit, on date: Date) {
        guard let i = data.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let key = PlannerDate.key(date)
        if data.habits[i].completedDates.contains(key) { data.habits[i].completedDates.remove(key) }
        else { data.habits[i].completedDates.insert(key) }
    }
}
