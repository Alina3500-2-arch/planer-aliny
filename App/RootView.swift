import SwiftUI

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            TodayView().tabItem { Label("Сегодня", systemImage: "house.fill") }.tag(0)
            CalendarPlaceholder().tabItem { Label("Календарь", systemImage: "calendar") }.tag(1)
            StatisticsView().tabItem { Label("Статистика", systemImage: "chart.bar") }.tag(2)
            SettingsView().tabItem { Label("Настройки", systemImage: "gearshape") }.tag(3)
        }.tint(Color.accentPurple).fontDesign(.rounded)
    }
}

private struct CalendarPlaceholder: View { var body: some View { NavigationStack { Text("Календарь").font(.largeTitle.bold()).navigationTitle("План") } } }
private struct SettingsView: View { var body: some View { NavigationStack { Form { Section("Планер Алины") { Text("Данные хранятся на этом iPhone") } }.navigationTitle("Настройки") } } }

struct StatisticsView: View {
    @EnvironmentObject var repo: PlannerRepository
    var body: some View {
        NavigationStack { VStack(spacing: 22) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 52)).foregroundStyle(Color.accentPurple)
            Text("Статистика").font(.largeTitle.bold())
            Text("Завершено задач: \(repo.data.tasks.filter(\.isDone).count)").foregroundStyle(.secondary)
        }.navigationTitle("Прогресс") }
    }
}
