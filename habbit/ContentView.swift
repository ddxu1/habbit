import SwiftUI
import CoreData

// MARK: - Frequency Enum
enum HabitFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case weekdays = "Weekdays Only"
    
    var systemImage: String {
        switch self {
        case .daily: return "calendar"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar.badge.plus"
        case .weekdays: return "briefcase"
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)],
        animation: .default)
    private var habits: FetchedResults<Habit>
    
    @State private var showingAddHabit = false
    @State private var isDarkMode = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(habits) { habit in
                    HabitRowView(habit: habit)
                }
                .onDelete(perform: deleteHabits)
            }
            .navigationTitle("Habits")
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isDarkMode.toggle() }) {
                        Image(systemName: isDarkMode ? "sun.max" : "moon")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddHabit = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
        }
    }
    
    private func deleteHabits(offsets: IndexSet) {
        withAnimation {
            offsets.map { habits[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Save error: \(error)")
        }
    }
}

// MARK: - Habit Row View
struct HabitRowView: View {
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var viewContext
    
    private var streakUnit: String {
            let frequency = HabitFrequency(rawValue: habit.frequency ?? "Daily") ?? .daily
            switch frequency {
            case .daily, .weekdays:
                return "day"
            case .weekly:
                return "week"
            case .monthly:
                return "month"
            }
        }
        
        private var frequencyIcon: String {
            let frequency = HabitFrequency(rawValue: habit.frequency ?? "Daily") ?? .daily
            return frequency.systemImage
        }
    
    private var isCompletedToday: Bool {
        guard let completions = habit.completions as? Set<Completion> else { return false }
        return completions.contains { completion in
            Calendar.current.isDateInToday(completion.date ?? Date())
        }
    }
    
    private var currentStreak: Int {
        guard let completions = habit.completions as? Set<Completion> else { return 0 }
        let sortedDates = completions.compactMap { $0.date }.sorted(by: >)
        
        let frequency = HabitFrequency(rawValue: habit.frequency ?? "Daily") ?? .daily
        var streak = 0
        var currentDate = Date()
        
        for date in sortedDates {
            if shouldCountForStreak(date: date, currentDate: currentDate, frequency: frequency) {
                streak += 1
                currentDate = nextExpectedDate(from: currentDate, frequency: frequency, backwards: true)
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func shouldCountForStreak(date: Date, currentDate: Date, frequency: HabitFrequency) -> Bool {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            return calendar.isDate(date, inSameDayAs: currentDate)
        case .weekly:
            return calendar.isDate(date, equalTo: currentDate, toGranularity: .weekOfYear)
        case .monthly:
            return calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
        case .weekdays:
            let weekday = calendar.component(.weekday, from: currentDate)
            // Skip weekends (1 = Sunday, 7 = Saturday)
            if weekday == 1 || weekday == 7 {
                return false
            }
            return calendar.isDate(date, inSameDayAs: currentDate)
        }
    }
    
    private func nextExpectedDate(from date: Date, frequency: HabitFrequency, backwards: Bool = false) -> Date {
        let calendar = Calendar.current
        let multiplier = backwards ? -1 : 1
        
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: multiplier, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: multiplier, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: multiplier, to: date) ?? date
        case .weekdays:
            var nextDate = calendar.date(byAdding: .day, value: multiplier, to: date) ?? date
            let weekday = calendar.component(.weekday, from: nextDate)
            // Skip weekends
            if weekday == 1 { // Sunday
                nextDate = calendar.date(byAdding: .day, value: backwards ? -2 : 1, to: nextDate) ?? nextDate
            } else if weekday == 7 { // Saturday
                nextDate = calendar.date(byAdding: .day, value: backwards ? -1 : 2, to: nextDate) ?? nextDate
            }
            return nextDate
        }
    }
    
    var body: some View {
        HStack {
            Button(action: toggleCompletion) {
                Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompletedToday ? .green : .gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name ?? "Unknown Habit")
                    .font(.headline)
                
                HStack {
                    Text("🔥 \(currentStreak) \(streakUnit) streak")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: frequencyIcon)
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(habit.frequency ?? "Daily")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    private func toggleCompletion() {
        withAnimation {
            if isCompletedToday {
                // Remove today's completion
                if let completions = habit.completions as? Set<Completion> {
                    for completion in completions {
                        if Calendar.current.isDateInToday(completion.date ?? Date()) {
                            viewContext.delete(completion)
                            break
                        }
                    }
                }
            } else {
                // Add today's completion
                let completion = Completion(context: viewContext)
                completion.date = Date()
                completion.habit = habit
            }
            
            saveContext()
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Save error: \(error)")
        }
    }
}

// MARK: - Add Habit View
struct AddHabitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var habitName = ""
    @State private var selectedFrequency: HabitFrequency = .daily
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Habit Name", text: $habitName)
                }
                
                Section(header: Text("Frequency")) {
                    ForEach(HabitFrequency.allCases, id: \.self) { frequency in
                        HStack {
                            Image(systemName: frequency.systemImage)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(frequency.rawValue)
                                    .font(.body)
                                
                                Text(frequencyDescription(frequency))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedFrequency == frequency {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFrequency = frequency
                        }
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(habitName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func frequencyDescription(_ frequency: HabitFrequency) -> String {
        switch frequency {
        case .daily:
            return "Every single day"
        case .weekly:
            return "Once per week"
        case .monthly:
            return "Once per month"
        case .weekdays:
            return "Monday through Friday only"
        }
    }
    
    private func saveHabit() {
        let newHabit = Habit(context: viewContext)
        newHabit.name = habitName.trimmingCharacters(in: .whitespaces)
        newHabit.frequency = selectedFrequency.rawValue
        newHabit.createdDate = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save error: \(error)")
        }
    }
}

// MARK: - Core Data Model Extensions
// Add this to a new Swift file or at the bottom of ContentView.swift

extension Habit {
    static var example: Habit {
        let context = PersistenceController.preview.container.viewContext
        let habit = Habit(context: context)
        habit.name = "Drink Water"
        habit.createdDate = Date()
        return habit
    }
}

extension Completion {
    static var example: Completion {
        let context = PersistenceController.preview.container.viewContext
        let completion = Completion(context: context)
        completion.date = Date()
        return completion
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
