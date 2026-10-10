import SwiftUI
import Foundation

// Independent storage: never modifies the existing planner.data.v1 archive.
struct ResultWork: Identifiable, Codable {
    var id = UUID()
    var title = ""
    var purpose = ""
    var impact = ""
    var test = ""
    var finish = ""
    var minutes = 60
    var spent: TimeInterval = 0
    var startedAt: Date?
    var extensions = 0
    var completed = false
    var outcome = ""
}

struct ResultEvening: Codable {
    var impact = ""
    var result = ""
    var wasted = ""
    var tomorrow = ""
}

struct ResultRecord: Codable {
    var monthKey = ""
    var target: Double = 100000
    var received: Double = 0
    var mainAction = ""
    var works: [ResultWork] = []
    var evenings: [String: ResultEvening] = [:]
}

@MainActor final class ResultStore: ObservableObject {
    private let key = "planner.result-mode.v1"
    @Published var value: ResultRecord { didSet { save() } }

    init() {
        let month = Date().formatted(.dateTime.year().month(.twoDigits))
        if let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode(ResultRecord.self, from: data) {
            value = stored
        } else {
            value = ResultRecord(monthKey: month)
        }
        if value.monthKey != month {
            value.monthKey = month
            value.received = 0
            value.mainAction = ""
        }
    }
    func save() {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    func update(_ item: ResultWork) {
        guard let index = value.works.firstIndex(where: { $0.id == item.id }) else { return }
        value.works[index] = item
    }
    func elapsed(_ item: ResultWork, now: Date = Date()) -> TimeInterval {
        item.spent + max(0, item.startedAt.map { now.timeIntervalSince($0) } ?? 0)
    }
    func toggle(_ item: ResultWork) {
        var updated = item
        if let start = updated.startedAt {
            updated.spent += max(0, Date().timeIntervalSince(start))
            updated.startedAt = nil
        } else {
            updated.startedAt = Date()
        }
        update(updated)
    }
    func extend(_ item: ResultWork, reason: String) {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var updated = item
        updated.minutes += 15
        updated.extensions += 1
        updated.outcome = (updated.outcome.isEmpty ? "" : updated.outcome + "\n") + "Продление: " + reason
        update(updated)
    }
    func finish(_ item: ResultWork, outcome: String) {
        var updated = item
        if let start = updated.startedAt {
            updated.spent += max(0, Date().timeIntervalSince(start))
            updated.startedAt = nil
        }
        updated.completed = true
        updated.outcome = outcome
        update(updated)
    }
}

struct ResultDashboardView: View {
    @StateObject private var store = ResultStore()
    @State private var showGoal = false
    @State private var showNew = false
    @State private var showEvening = false
    @State private var selected: UUID?

    private var active: [ResultWork] { store.value.works.filter { !$0.completed } }
    private var progress: Double {
        guard store.value.target > 0 else { return 0 }
        return min(1, max(0, store.value.received / store.value.target))
    }
    private var rubles: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: "RUB").precision(.fractionLength(0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("МОЙ ФОКУС").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(.secondary)
                    Text("Режим результата").font(.title2.weight(.semibold))
                }
                Spacer()
                Button { showGoal = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.title3)
                }.accessibilityLabel("Настроить денежную цель")
            }
            HStack(alignment: .firstTextBaseline) {
                Text(store.value.target, format: rubles).font(.title.bold()).minimumScaleFactor(0.7).lineLimit(1)
                Spacer()
                Text("\(Int(progress * 100))%").font(.headline).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                Capsule().fill(Color.pink.opacity(0.11))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color(red: 0.73, green: 0.44, blue: 0.55))
                            .frame(width: max(0, proxy.size.width * progress))
                    }
            }.frame(height: 8)
            HStack {
                Text("Получено: \(store.value.received.formatted(rubles))")
                Spacer()
                Text("Осталось: \(max(0, store.value.target - store.value.received).formatted(rubles))")
            }.font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Одно главное действие сегодня").font(.subheadline.weight(.semibold))
            TextField("Что приблизит меня к цели?", text: $store.value.mainAction, axis: .vertical)
                .lineLimit(1...2)
                .padding(12)
                .background(Color(red: 0.99, green: 0.96, blue: 0.97), in: RoundedRectangle(cornerRadius: 13))
            HStack {
                Text("РАБОЧИЕ ЗАДАЧИ").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button { showNew = true } label: { Label("Новая", systemImage: "plus.circle.fill") }
                    .font(.subheadline)
            }.padding(.top, 4)
            if active.isEmpty {
                Text("Нет активных рабочих задач. Добавь одну с измеримым результатом.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(active) { item in
                Button { selected = item.id } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.startedAt == nil ? "play.circle" : "timer")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("\(item.minutes) мин · \(item.extensions) продлений")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(.vertical, 7)
                }.buttonStyle(.plain)
            }
            Button { showEvening = true } label: {
                Label("Итоги дня · 4 вопроса", systemImage: "moon.stars")
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }
        }
        .padding(19)
        .background(.white, in: RoundedRectangle(cornerRadius: 25))
        .sheet(isPresented: $showGoal) { GoalSheet(store: store) }
        .sheet(isPresented: $showNew) { NewResultTaskSheet(store: store) }
        .sheet(isPresented: $showEvening) { EveningSheet(store: store) }
        .sheet(item: Binding(
            get: { selected.map { SelectedWork(id: $0) } },
            set: { selected = $0?.id }
        )) { selection in
            ResultTimerSheet(store: store, workID: selection.id)
        }
    }
}

private struct SelectedWork: Identifiable { let id: UUID }

private struct GoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ResultStore
    @State private var target = ""
    @State private var received = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Цель на месяц") {
                    TextField("Сколько хочу получить, ₽", text: $target).keyboardType(.decimalPad)
                    TextField("Фактически получено, ₽", text: $received).keyboardType(.decimalPad)
                }
                Section {
                    Text("Учитывай только реальные поступления в личный доход, не обещания и не оборот бизнеса.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Денежный фокус")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let t = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let r = Double(received.replacingOccurrences(of: ",", with: ".")) ?? 0
                        store.value.target = max(0, t)
                        store.value.received = max(0, r)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            target = String(format: "%.0f", store.value.target)
            received = String(format: "%.0f", store.value.received)
        }
    }
}

private struct NewResultTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ResultStore
    @State private var work = ResultWork()
    @State private var expanded = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Рабочая задача") {
                    TextField("Что хочу сделать?", text: $work.title)
                    TextField("Ради какого результата?", text: $work.purpose, axis: .vertical)
                    TextField("Самая быстрая проверка", text: $work.test, axis: .vertical)
                }
                Section("Лимит времени") {
                    Picker("Минут", selection: $work.minutes) {
                        ForEach([15, 30, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) мин").tag(minutes)
                        }
                    }
                }
                Section("Критерий завершения") {
                    TextField("Когда можно остановиться?", text: $work.finish, axis: .vertical)
                }
                Section {
                    DisclosureGroup("Дополнительно", isExpanded: $expanded) {
                        TextField("Как повлияет на деньги или цель?", text: $work.impact, axis: .vertical)
                    }
                }
                Section {
                    Text("Не обязательно делать идеально. Сначала проверь, нужен ли результат.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Зачем я это делаю?")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        work.title = work.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.value.works.insert(work, at: 0)
                        dismiss()
                    }.disabled(work.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ResultTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ResultStore
    let workID: UUID
    @State private var now = Date()
    @State private var reason = ""
    @State private var outcome = ""
    @State private var showExtend = false
    @State private var showFinish = false
    private var work: ResultWork? { store.value.works.first { $0.id == workID } }

    var body: some View {
        NavigationStack {
            Group {
                if let work {
                    let elapsed = store.elapsed(work, now: now)
                    let total = Double(work.minutes * 60)
                    let remaining = max(0, total - elapsed)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(work.title).font(.title2.bold())
                            if !work.purpose.isEmpty { Text("Цель: " + work.purpose) }
                            if !work.finish.isEmpty { Text("Готово, когда: " + work.finish).font(.subheadline).foregroundStyle(.secondary) }
                            Text(remaining <= 0 ? "СТОП. ВРЕМЯ ВЫШЛО" : timeString(remaining))
                                .font(.system(size: 33, weight: .bold, design: .rounded))
                                .foregroundStyle(remaining <= 0 ? .red : .primary)
                                .monospacedDigit()
                            ProgressView(value: min(1, elapsed / max(1, total)))
                                .tint(Color(red: 0.73, green: 0.44, blue: 0.55))
                            Text("Прошло \(timeString(elapsed)) из \(work.minutes) мин · Продлений: \(work.extensions)")
                                .font(.caption).foregroundStyle(.secondary)
                            if remaining <= 0 {
                                Text("Что конкретно ты получила за это время?")
                                    .font(.headline)
                            } else if remaining <= 300 && work.startedAt != nil {
                                Text("Ты приближаешься к результату или увлеклась настройками?")
                                    .font(.subheadline)
                            }
                            Button(work.startedAt == nil ? "Начать / продолжить" : "Пауза") {
                                store.toggle(work)
                                now = Date()
                            }.buttonStyle(.borderedProminent).tint(Color(red: 0.73, green: 0.44, blue: 0.55))
                            Button("Завершить и зафиксировать результат") { showFinish = true }
                            Button("Пересмотреть гипотезу") {
                                store.finish(work, outcome: "Гипотеза требует пересмотра")
                                dismiss()
                            }
                            Button("Добавить 15 минут с объяснением") { showExtend = true }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
                    }
                } else {
                    Text("Задача не найдена")
                }
            }
            .navigationTitle("Лимит времени")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .alert("Зачем продлить?", isPresented: $showExtend) {
            TextField("Причина", text: $reason)
            Button("Продлить") {
                if let work { store.extend(work, reason: reason) }
                reason = ""
            }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Продление будет учтено в задаче.") }
        .alert("Что получилось?", isPresented: $showFinish) {
            TextField("Конкретный результат", text: $outcome)
            Button("Завершить") {
                if let work { store.finish(work, outcome: outcome) }
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Зафиксируй результат, даже если он небольшой.") }
    }
    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

private struct EveningSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ResultStore
    @State private var entry = ResultEvening()
    private var day: String { PlannerDate.key(Date()) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Что приблизило к цели?") { TextField("Главное действие", text: $entry.impact, axis: .vertical) }
                Section("Какой конкретный результат?") { TextField("Цифры, ответы, оплаты", text: $entry.result, axis: .vertical) }
                Section("Где увлеклась деталями?") { TextField("Что можно было сделать проще", text: $entry.wasted, axis: .vertical) }
                Section("Что завтра даст максимум?") { TextField("Одно действие", text: $entry.tomorrow, axis: .vertical) }
            }
            .navigationTitle("Итоги дня")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.value.evenings[day] = entry
                        dismiss()
                    }
                }
            }
        }
        .onAppear { entry = store.value.evenings[day] ?? ResultEvening() }
    }
}
