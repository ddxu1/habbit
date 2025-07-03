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
    sortDescriptors: [NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true), NSSortDescriptor(keyPath: \Habit.name, ascending: true)],
    animation: .default)
private var habits: FetchedResults<Habit>

@State private var showingAddHabit = false
@State private var isDarkMode = false
@State private var editMode: EditMode = .inactive

var body: some View {
    NavigationView {
        ZStack {
            // Dark blue background similar to Copilot
            Color(red: 0.08, green: 0.12, blue: 0.20)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Text("Habbit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation {
                                if editMode == .inactive {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }) {
                            Image(systemName: editMode == .active ? "checkmark" : "line.3.horizontal")
                                .foregroundColor(editMode == .active ? Color(red: 0.4, green: 0.8, blue: 1.0) : .white)
                                .font(.title3)
                        }
                        
                        Button(action: { showingAddHabit = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(red: 0.08, green: 0.12, blue: 0.20))
                
                // Habit list
                List {
                    ForEach(habits) { habit in
                        HabitRowView(habit: habit)
                            .listRowBackground(Color(red: 0.10, green: 0.14, blue: 0.22))
                    }
                    .onDelete(perform: deleteHabits)
                    .onMove(perform: editMode == .active ? moveHabits : nil)
                }
                .environment(\.editMode, $editMode)
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color(red: 0.08, green: 0.12, blue: 0.20))
            }
        }
        .navigationBarHidden(true)
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

private func moveHabits(from source: IndexSet, to destination: Int) {
    withAnimation {
        // Haptic feedback when moving items
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        var habitsArray = Array(habits)
        habitsArray.move(fromOffsets: source, toOffset: destination)
        
        // Update sort order for all habits
        for (index, habit) in habitsArray.enumerated() {
            habit.sortOrder = Int16(index)
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

// MARK: - Habit Row View
struct HabitRowView: View {
@ObservedObject var habit: Habit
@Environment(\.managedObjectContext) private var viewContext

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
    }// MARK: - App Entry Point


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
                .foregroundColor(isCompletedToday ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.gray.opacity(0.6))
                .font(.title2)
        }
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(habit.emoji ?? "📋")
                    .font(.title3)
                Text(habit.name ?? "Unknown Habit")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("🔥 \(currentStreak) \(streakUnit) streak")
                    .font(.caption)
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: frequencyIcon)
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                    Text(habit.frequency ?? "Daily")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                }
            }
        }
        
        Spacer()
    }
    .contentShape(Rectangle())
}

private func toggleCompletion() {
    withAnimation {
        // Light haptic feedback for completion toggle
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
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
@State private var selectedEmoji = "📋"

private let emojis = ["📋", "💧", "🏃‍♂️", "📚", "💪", "🧘‍♂️", "🥗", "😴", "🚶‍♂️", "📱", "🎯", "✍️", "🎵", "🌱", "☀️", "🏠", "💼", "🎨", "🔥", "⭐"]

var body: some View {
    NavigationView {
        Form {
            Section(header: Text("Habit Details")) {
                TextField("Habit Name", text: $habitName)
                    .frame(minHeight: 44) // Minimum tap target size
                    .padding(.vertical, 8) // Extra padding for easier tapping
            }
            
            Section(header: Text("Choose an Emoji")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 60, height: 60) // Increased from 44x44
                            .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(12) // Slightly larger corner radius
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEmoji = emoji
                                print("Selected emoji: \(emoji)") // Debug
                            }
                    }
                }
                .padding(.vertical, 8)
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
    newHabit.emoji = selectedEmoji
    newHabit.createdDate = Date()
    
    // Set sort order to be last
    let request: NSFetchRequest<Habit> = Habit.fetchRequest()
    let count = (try? viewContext.count(for: request)) ?? 0
    newHabit.sortOrder = Int16(count)
    
    do {
        try viewContext.save()
        dismiss()
    } catch {
        print("Save error: \(error)")
    }
}
}

// MARK: - Edit Habit View
struct EditHabitView: View {
@ObservedObject var habit: Habit
@Environment(\.managedObjectContext) private var viewContext
@Environment(\.dismiss) private var dismiss

@State private var editedName: String
@State private var editedFrequency: HabitFrequency
@State private var editedEmoji: String

private let emojis = ["📋", "💧", "🏃‍♂️", "📚", "💪", "🧘‍♂️", "🥗", "😴", "🚶‍♂️", "📱", "🎯", "✍️", "🎵", "🌱", "☀️", "🏠", "💼", "🎨", "🔥", "⭐"]

init(habit: Habit) {
    self.habit = habit
    _editedName = State(initialValue: habit.name ?? "")
    _editedFrequency = State(initialValue: HabitFrequency(rawValue: habit.frequency ?? "Daily") ?? .daily)
    _editedEmoji = State(initialValue: habit.emoji ?? "📋")
}

var body: some View {
    NavigationView {
        Form {
            Section(header: Text("Habit Details")) {
                TextField("Habit Name", text: $editedName)
                    .frame(minHeight: 44) // Minimum tap target size
                    .padding(.vertical, 8) // Extra padding for easier tapping
            }
            
            Section(header: Text("Choose an Emoji")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 60, height: 60) // Increased from 44x44
                            .background(editedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(12) // Slightly larger corner radius
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editedEmoji = emoji
                            }
                    }
                }
                .padding(.vertical, 8)
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
                        
                        if editedFrequency == frequency {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editedFrequency = frequency
                    }
                }
            }
            
            Section {
                Button("Delete Habit", role: .destructive) {
                    deleteHabit()
                }
            }
        }
        .navigationTitle("Edit Habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
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

private func saveChanges() {
    habit.name = editedName.trimmingCharacters(in: .whitespaces)
    habit.frequency = editedFrequency.rawValue
    habit.emoji = editedEmoji
    
    do {
        try viewContext.save()
        dismiss()
    } catch {
        print("Save error: \(error)")
    }
}

private func deleteHabit() {
    viewContext.delete(habit)
    
    do {
        try viewContext.save()
        dismiss()
    } catch {
        print("Delete error: \(error)")
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
