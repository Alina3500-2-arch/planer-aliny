import WidgetKit
import SwiftUI

struct PlannerEntry: TimelineEntry { let date: Date; let data: PlannerData }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PlannerEntry { .init(date: Date(), data: PlannerData()) }
    func getSnapshot(in context: Context, completion: @escaping (PlannerEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlannerEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: Date())!
        completion(Timeline(entries: [load()], policy: .after(next)))
    }
    private func load() -> PlannerEntry {
        let defaults = UserDefaults(suiteName: PlannerRepository.suite)
        let data = defaults?.data(forKey: PlannerRepository.storageKey).flatMap { try? JSONDecoder().decode(PlannerData.self, from: $0) } ?? PlannerData()
        return .init(date: Date(), data: data)
    }
}

struct PlannerWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PlannerEntry
    private var tasks: [PlannerTask] { entry.data.tasks.filter { $0.dateKey == PlannerDate.key(entry.date) } }
    private var doneHabits: Int { entry.data.habits.filter { $0.completedDates.contains(PlannerDate.key(entry.date)) }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(PlannerDate.weekdayFormatter.string(from: entry.date).capitalized).font(.headline); Spacer(); Text("\(doneHabits)/\(entry.data.habits.count)").foregroundStyle(Color.accentPurple) }
            if family == .systemSmall {
                Text(tasks.first?.title ?? "День свободен").font(.title3.bold()).lineLimit(3)
                Spacer(); ProgressView(value: Double(doneHabits), total: Double(max(entry.data.habits.count, 1))).tint(Color.accentPurple)
            } else {
                ForEach(tasks.prefix(family == .systemLarge ? 6 : 3)) { task in HStack { Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.accentPurple); Text(task.title).lineLimit(1) } }
                if tasks.isEmpty { Text("Добавьте задачи в планер").foregroundStyle(.secondary) }
                Spacer()
                Text("Привычки: \(doneHabits) из \(entry.data.habits.count)").font(.caption).foregroundStyle(.secondary)
            }
        }.containerBackground(Color.white, for: .widget)
    }
}

struct PlannerWidget: Widget {
    let kind = "AlinaPlannerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { PlannerWidgetView(entry: $0) }
            .configurationDisplayName("Планер Алины")
            .description("Задачи и привычки на сегодня")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main struct PlannerWidgetBundle: WidgetBundle { var body: some Widget { PlannerWidget() } }

