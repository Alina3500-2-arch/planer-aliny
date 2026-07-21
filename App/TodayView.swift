import SwiftUI

struct TodayView: View {
    @EnvironmentObject var repo: PlannerRepository
    @State private var selectedDate = Date()
    @State private var addMode: AddMode?
    @State private var draft = ""
    enum AddMode: Identifiable { case today, tomorrow, habit; var id: Int { hashValue } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    header
                    WeekStrip(selectedDate: $selectedDate)
                    HabitCard(date: selectedDate) { addMode = .habit }
                    TaskCard(title: "Задачи", date: selectedDate) { addMode = .today }
                    TaskCard(title: "Задачи на завтра", date: tomorrow) { addMode = .tomorrow }
                    NoteCard()
                }.padding(.horizontal, 18).padding(.bottom, 28)
            }.background(Color.plannerBackground.ignoresSafeArea())
             .toolbar(.hidden, for: .navigationBar)
             .sheet(item: $addMode) { mode in addSheet(mode) }
        }
    }

    private var tomorrow: Date { PlannerDate.calendar.date(byAdding: .day, value: 1, to: selectedDate)! }
    private var header: some View {
        HStack {
            Button(action: {}) { Image(systemName: "gearshape") }
            Spacer()
            VStack(spacing: 3) {
                Text(PlannerDate.weekdayFormatter.string(from: selectedDate).capitalized).font(.title.bold())
                Text(PlannerDate.fullFormatter.string(from: selectedDate)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { selectedDate = Date() }) { Image(systemName: "calendar") }
        }.font(.title2).foregroundStyle(.primary).padding(.top, 8)
    }

    @ViewBuilder private func addSheet(_ mode: AddMode) -> some View {
        NavigationStack {
            Form { TextField(mode == .habit ? "Название привычки" : "Новая задача", text: $draft) }
                .navigationTitle(mode == .habit ? "Новая привычка" : "Новая задача")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { draft = ""; addMode = nil } }
                    ToolbarItem(placement: .confirmationAction) { Button("Добавить") {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        if mode == .habit { repo.data.habits.append(Habit(title: text)) }
                        else { repo.addTask(text, on: mode == .today ? selectedDate : tomorrow) }
                        draft = ""; addMode = nil
                    }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }.presentationDetents([.medium])
    }
}

private struct WeekStrip: View {
    @Binding var selectedDate: Date
    private var days: [Date] {
        let cal = PlannerDate.calendar
        let start = cal.dateInterval(of: .weekOfYear, for: selectedDate)!.start
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let selected = PlannerDate.calendar.isDate(day, inSameDayAs: selectedDate)
                Button { selectedDate = day } label: {
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).textCase(.uppercase).foregroundStyle(selected ? Color.accentPurple : .secondary)
                        Text(day.formatted(.dateTime.day())).font(.headline).foregroundStyle(.primary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                     .background(selected ? Color.accentPurple.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
        }
    }
}

private struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 28)).shadow(color: .black.opacity(0.035), radius: 16, y: 6) }
}

private struct CardTitle: View {
    let icon: String; let title: String; let count: String; let add: () -> Void
    var body: some View { HStack(spacing: 12) {
        Image(systemName: icon).foregroundStyle(Color.accentPurple).frame(width: 36, height: 36).background(Color.accentPurple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        Text(title).font(.title2.bold()); Text(count).foregroundStyle(.secondary); Spacer()
        Button(action: add) { Image(systemName: "plus").font(.title2) }.foregroundStyle(Color.accentPurple)
    } }
}

private struct HabitCard: View {
    @EnvironmentObject var repo: PlannerRepository
    let date: Date; let add: () -> Void
    var completed: Int { repo.data.habits.filter { $0.completedDates.contains(PlannerDate.key(date)) }.count }
    var body: some View { Card { VStack(spacing: 18) {
        CardTitle(icon: "arrow.trianglehead.2.clockwise.rotate.90", title: "Привычки", count: "\(completed)/\(repo.data.habits.count)", add: add)
        ForEach(repo.data.habits) { habit in
            HStack(spacing: 12) {
                Button { repo.toggleHabit(habit, on: date) } label: {
                    Image(systemName: habit.completedDates.contains(PlannerDate.key(date)) ? "checkmark.square.fill" : "square").font(.title2).foregroundStyle(habit.completedDates.contains(PlannerDate.key(date)) ? Color.accentPurple : .secondary)
                }
                Text(habit.title).lineLimit(1); Spacer()
                HStack(spacing: 5) { ForEach(-3...3, id: \.self) { offset in
                    let d = PlannerDate.calendar.date(byAdding: .day, value: offset, to: date)!
                    Circle().fill(habit.completedDates.contains(PlannerDate.key(d)) ? Color.accentPurple : Color.gray.opacity(0.12)).frame(width: 10, height: 10)
                } }
            }
        }
    } } }
}

private struct TaskCard: View {
    @EnvironmentObject var repo: PlannerRepository
    let title: String; let date: Date; let add: () -> Void
    var tasks: [PlannerTask] { repo.tasks(on: date) }
    var body: some View { Card { VStack(spacing: 16) {
        CardTitle(icon: title.contains("завтра") ? "calendar.badge.clock" : "checkmark.square", title: title, count: tasks.isEmpty ? "" : "\(tasks.filter(\.isDone).count)/\(tasks.count)", add: add)
        if tasks.isEmpty { Text("Пока ничего не запланировано").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        ForEach(tasks) { task in
            HStack {
                Button { repo.toggleTask(task) } label: { Image(systemName: task.isDone ? "checkmark.square.fill" : "square").font(.title2).foregroundStyle(task.isDone ? Color.accentPurple : .secondary) }
                Text(task.title).strikethrough(task.isDone).foregroundStyle(task.isDone ? .secondary : .primary); Spacer()
            }.swipeActions { Button(role: .destructive) { repo.deleteTask(task) } label: { Label("Удалить", systemImage: "trash") } }
        }
    } } }
}

private struct NoteCard: View {
    @EnvironmentObject var repo: PlannerRepository
    var body: some View { Card { VStack(alignment: .leading, spacing: 14) {
        HStack { Image(systemName: "pencil.line").foregroundStyle(Color.accentPurple); Text("Заметки").font(.title2.bold()) }
        TextField("Заметка самой себе…", text: $repo.data.note, axis: .vertical).lineLimit(2...5).padding(14).background(Color.plannerBackground, in: RoundedRectangle(cornerRadius: 16))
    } } }
}
