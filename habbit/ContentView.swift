import SwiftUI
import CoreData

// MARK: - Extensions
extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value >= 0x238d || unicodeScalars.count > 1)
    }
}

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
@State private var showingHeatMap = false
@State private var editingHabit: Habit? = nil
@State private var isDarkMode = false
@State private var editMode: EditMode = .inactive
@State private var showCompletedTasks = false

// Computed properties for habit categorization
private var activeHabits: [Habit] {
    habits.filter { habit in
        !isCompletedToday(habit) && isDueToday(habit)
    }
}

private var completedHabits: [Habit] {
    habits.filter { habit in
        isCompletedToday(habit)
    }
}

private var upcomingHabits: [Habit] {
    habits.filter { habit in
        !isCompletedToday(habit) && !isDueToday(habit)
    }
}

private func isCompletedToday(_ habit: Habit) -> Bool {
    guard let completions = habit.completions as? Set<Completion> else { return false }
    return completions.contains { completion in
        Calendar.current.isDateInToday(completion.date ?? Date())
    }
}

private func isDueToday(_ habit: Habit) -> Bool {
    let frequency = HabitFrequency(rawValue: habit.frequency ?? "Daily") ?? .daily
    let calendar = Calendar.current
    let today = Date()
    
    switch frequency {
    case .daily:
        return true
    case .weekdays:
        let weekday = calendar.component(.weekday, from: today)
        return weekday >= 2 && weekday <= 6 // Monday (2) to Friday (6)
    case .weekly:
        // Due every 7 days from creation date
        guard let createdDate = habit.createdDate else { return true }
        let daysSinceCreation = calendar.dateComponents([.day], from: createdDate, to: today).day ?? 0
        return daysSinceCreation % 7 == 0
    case .monthly:
        // Due every 30 days from creation date
        guard let createdDate = habit.createdDate else { return true }
        let daysSinceCreation = calendar.dateComponents([.day], from: createdDate, to: today).day ?? 0
        return daysSinceCreation % 30 == 0
    }
}

var body: some View {
    NavigationView {
        ZStack {
            // Dark blue background similar to Copilot
            Color(red: 0.08, green: 0.12, blue: 0.20)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Text("Stride")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { showingHeatMap = true }) {
                            Image(systemName: "chart.dots.scatter")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                        
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
                
                // Daily progress bar
                DailyProgressBar(habits: Array(habits), isDueToday: isDueToday, isCompletedToday: isCompletedToday)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                
                // Habit list
                List {
                    // Active habits (not completed today)
                    ForEach(activeHabits) { habit in
                        HabitRowView(habit: habit) {
                            editingHabit = habit
                        }
                        .listRowBackground(Color(red: 0.10, green: 0.14, blue: 0.22))
                    }
                    .onDelete(perform: deleteHabits)
                    .onMove(perform: editMode == .active ? moveHabits : nil)
                    
                    // Completed tasks section
                    if !completedHabits.isEmpty {
                        Section {
                            Button(action: {
                                withAnimation {
                                    showCompletedTasks.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Completed Today (\(completedHabits.count))")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: showCompletedTasks ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color(red: 0.08, green: 0.12, blue: 0.20))
                            
                            if showCompletedTasks {
                                ForEach(completedHabits) { habit in
                                    HabitRowView(habit: habit) {
                                        editingHabit = habit
                                    }
                                    .listRowBackground(Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.7))
                                }
                            }
                        }
                    }
                    
                    // Upcoming tasks section (not due today)
                    if !upcomingHabits.isEmpty {
                        Section {
                            HStack {
                                Text("Upcoming (\(upcomingHabits.count))")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color(red: 0.08, green: 0.12, blue: 0.20))
                            
                            ForEach(upcomingHabits) { habit in
                                HabitRowView(habit: habit) {
                                    editingHabit = habit
                                }
                                .listRowBackground(Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.5))
                                .disabled(true) // Disable interaction for upcoming tasks
                            }
                        }
                    }
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
        .sheet(isPresented: $showingHeatMap) {
            HeatMapView()
        }
        .sheet(item: $editingHabit) { habit in
            EditHabitView(habit: habit)
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

// MARK: - Daily Progress Bar
struct DailyProgressBar: View {
    let habits: [Habit]
    let isDueToday: (Habit) -> Bool
    let isCompletedToday: (Habit) -> Bool
    private let calendar = Calendar.current
    
    @State private var animationOffset: CGFloat = -50
    @State private var barWidth: CGFloat = 0
    
    private var todaysHabits: [Habit] {
        habits.filter { habit in
            isDueToday(habit)
        }
    }
    
    private var completedTodayCount: Int {
        todaysHabits.filter { habit in
            isCompletedToday(habit)
        }.count
    }
    
    private var progress: Double {
        guard !todaysHabits.isEmpty else { return 0 }
        return Double(completedTodayCount) / Double(todaysHabits.count)
    }
    
    private var isComplete: Bool {
        !todaysHabits.isEmpty && progress == 1.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(progressGradient)
                    .frame(width: max(0, CGFloat(progress) * geometry.size.width), height: 6)
                    .animation(.easeInOut(duration: 0.3), value: completedTodayCount)
                    .overlay(
                        // Shine effect when complete
                        isComplete ? 
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.3), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40)
                            .offset(x: animationOffset)
                        : nil
                    )
            }
            .onAppear {
                barWidth = geometry.size.width
                if isComplete {
                    startShineAnimation()
                }
            }
            .onChange(of: progress) { _, newValue in
                if newValue == 1.0 && !todaysHabits.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        startShineAnimation()
                    }
                }
            }
        }
        .frame(height: 6)
    }
    
    private var progressGradient: LinearGradient {
        if isComplete {
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.8, blue: 0.2),  // Green
                    Color(red: 0.4, green: 0.9, blue: 0.4),  // Light green
                    Color(red: 0.6, green: 1.0, blue: 0.6)   // Bright green
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.6, blue: 1.0),  // Blue
                    Color(red: 0.4, green: 0.8, blue: 1.0)   // Light blue
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func startShineAnimation() {
        animationOffset = -50
        withAnimation(.easeInOut(duration: 1.5)) {
            animationOffset = barWidth + 50
        }
    }
    
}

// MARK: - Habit Row View
struct HabitRowView: View {
@ObservedObject var habit: Habit
@Environment(\.managedObjectContext) private var viewContext
let onTap: () -> Void

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
        // Large completion area: checkbox + name + streak
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
                
                Text("🔥 \(currentStreak) \(streakUnit) streak")
                    .font(.caption)
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCompletion() // Mark/unmark habit
        }
        
        Spacer()
        
        // Frequency display (non-interactive)
        HStack(spacing: 4) {
            Image(systemName: frequencyIcon)
                .font(.caption2)
                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
            Text(habit.frequency ?? "Daily")
                .font(.caption2)
                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
        }
        
        // Edit button - only the chevron triggers editing
        Button(action: onTap) {
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.6))
                .font(.caption)
                .padding(.leading, 8)
        }
    }
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
@State private var customEmoji = ""
@State private var showingCustomEmojiInput = false
@FocusState private var isCustomEmojiFieldFocused: Bool

private let popularEmojis = ["🏃‍♂️", "🧘‍♂️", "💪", "📚", "🥗", "😴"]

var body: some View {
    NavigationView {
        Form {
            Section(header: Text("Habit Details")) {
                TextField("Habit Name", text: $habitName)
                    .padding(.vertical, 12) // Increase tap margin
                    .padding(.horizontal, 4) // Small horizontal padding
                    .contentShape(Rectangle()) // Extend tap area to full width
            }
            
            Section(header: Text("Choose an Emoji")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Horizontal scrollable emoji slider
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(popularEmojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedEmoji = emoji
                                        customEmoji = "" // Reset custom emoji when selecting pre-built
                                        showingCustomEmojiInput = false
                                    }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Custom emoji option
                    HStack {
                        Text("Or use your own:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            // Hidden text field that opens emoji keyboard
                            TextField("", text: $customEmoji)
                                .opacity(0)
                                .frame(width: 1, height: 1)
                                .focused($isCustomEmojiFieldFocused)
                                .onChange(of: customEmoji) { _, newValue in
                                    // Validate and filter to only allow emojis, limit to 1
                                    let filtered = newValue.filter { $0.isEmoji }
                                    if filtered != newValue {
                                        customEmoji = filtered
                                    }
                                    // Only allow one emoji
                                    if filtered.count > 1 {
                                        customEmoji = String(filtered.prefix(1))
                                    }
                                    if !customEmoji.isEmpty {
                                        selectedEmoji = customEmoji
                                        isCustomEmojiFieldFocused = false // Close keyboard after selection
                                    }
                                }
                            
                            // Visible button
                            Button(action: {
                                customEmoji = "" // Clear for fresh input
                                isCustomEmojiFieldFocused = true // Open emoji keyboard
                            }) {
                                HStack {
                                    Text(!customEmoji.isEmpty ? customEmoji : "😀")
                                        .font(.title3)
                                    
                                    if customEmoji.isEmpty {
                                        Text("Tap to choose")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(getCustomEmojiBackground())
                                .cornerRadius(8)
                            }
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

private func getCustomEmojiBackground() -> Color {
    if isCustomEmojiFieldFocused {
        return Color.clear
    } else if !customEmoji.isEmpty && selectedEmoji == customEmoji {
        return Color.blue.opacity(0.2) // Blue background when custom emoji is selected
    } else {
        return Color.gray.opacity(0.1)
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
@State private var customEmoji = ""
@State private var showingCustomEmojiInput = false
@FocusState private var isCustomEmojiFieldFocused: Bool

private let popularEmojis = ["🏃‍♂️", "🧘‍♂️", "💪", "📚", "🥗", "😴"]

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
                    .padding(.vertical, 12) // Increase tap margin
                    .padding(.horizontal, 4) // Small horizontal padding
                    .contentShape(Rectangle()) // Extend tap area to full width
            }
            
            Section(header: Text("Choose an Emoji")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Horizontal scrollable emoji slider
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(popularEmojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(editedEmoji == emoji ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editedEmoji = emoji
                                        customEmoji = "" // Reset custom emoji when selecting pre-built
                                        showingCustomEmojiInput = false
                                    }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Custom emoji option
                    HStack {
                        Text("Or use your own:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            // Hidden text field that opens emoji keyboard
                            TextField("", text: $customEmoji)
                                .opacity(0)
                                .frame(width: 1, height: 1)
                                .focused($isCustomEmojiFieldFocused)
                                .onChange(of: customEmoji) { _, newValue in
                                    // Validate and filter to only allow emojis, limit to 1
                                    let filtered = newValue.filter { $0.isEmoji }
                                    if filtered != newValue {
                                        customEmoji = filtered
                                    }
                                    // Only allow one emoji
                                    if filtered.count > 1 {
                                        customEmoji = String(filtered.prefix(1))
                                    }
                                    if !customEmoji.isEmpty {
                                        editedEmoji = customEmoji
                                        isCustomEmojiFieldFocused = false // Close keyboard after selection
                                    }
                                }
                            
                            // Visible button
                            Button(action: {
                                customEmoji = "" // Clear for fresh input
                                isCustomEmojiFieldFocused = true // Open emoji keyboard
                            }) {
                                HStack {
                                    Text(!customEmoji.isEmpty ? customEmoji : "😀")
                                        .font(.title3)
                                    
                                    if customEmoji.isEmpty {
                                        Text("Tap to choose")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(getCustomEmojiBackground())
                                .cornerRadius(8)
                            }
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

private func getCustomEmojiBackground() -> Color {
    if isCustomEmojiFieldFocused {
        return Color.clear
    } else if !customEmoji.isEmpty && editedEmoji == customEmoji {
        return Color.blue.opacity(0.2) // Blue background when custom emoji is selected
    } else {
        return Color.gray.opacity(0.1)
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

// MARK: - Heat Map Time Period
enum HeatMapPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "90 Days" 
    case year = "Year"
    
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
    
    var gridColumns: Int {
        switch self {
        case .week: return 7
        case .month: return 10 // 3 rows of ~10 days each
        case .quarter: return 15 // 6 rows of ~15 days each  
        case .year: return 26 // ~14 rows of 26 days each (taller layout)
        }
    }
}

// MARK: - Heat Map View
struct HeatMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true)],
        animation: .default)
    private var habits: FetchedResults<Habit>
    
    @State private var selectedPeriod: HeatMapPeriod = .quarter
    @State private var currentOffset: Int = 0 // 0 = most recent period, 1 = one period back, etc.
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    // Get date range based on selected period and offset
    private var dateRange: [Date] {
        let today = Date()
        let offsetDays = currentOffset * selectedPeriod.dayCount
        let endDate = calendar.date(byAdding: .day, value: -offsetDays, to: today) ?? today
        let startDate = calendar.date(byAdding: .day, value: -(selectedPeriod.dayCount - 1), to: endDate) ?? endDate
        
        var dates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    // Get formatted date range string
    private var dateRangeString: String {
        guard let startDate = dateRange.first, let endDate = dateRange.last else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if calendar.isDate(startDate, equalTo: endDate, toGranularity: .year) {
            // Same year
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(startFormatter.string(from: startDate)) - \(endFormatter.string(from: endDate))"
        } else {
            // Different years
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d, yyyy"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(startFormatter.string(from: startDate)) - \(endFormatter.string(from: endDate))"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.12, blue: 0.20)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                        
                        Text("Heat Map")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Period selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Time Period")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    ForEach(HeatMapPeriod.allCases, id: \.self) { period in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedPeriod = period
                                                currentOffset = 0 // Reset to current period when changing views
                                            }
                                        }) {
                                            Text(period.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedPeriod == period ? .white : Color.gray)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedPeriod == period ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color(red: 0.15, green: 0.20, blue: 0.30))
                                                .cornerRadius(8)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            
                            // Date range and navigation
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentOffset += 1
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                                            .font(.title3)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 2) {
                                        Text(dateRangeString)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                        
                                        if currentOffset > 0 {
                                            Text("\(currentOffset) period\(currentOffset == 1 ? "" : "s") ago")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if currentOffset > 0 {
                                                currentOffset -= 1
                                            }
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(currentOffset > 0 ? Color(red: 0.4, green: 0.8, blue: 1.0) : .gray)
                                            .font(.title3)
                                    }
                                    .disabled(currentOffset == 0)
                                }
                            }
                            
                            // Legend
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Daily Completion Rate")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    Text("Less")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    ForEach(0..<5) { intensity in
                                        Rectangle()
                                            .fill(colorForCompletion(Double(intensity) / 4.0))
                                            .frame(width: 12, height: 12)
                                            .cornerRadius(2)
                                    }
                                    
                                    Text("More")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Heat map grid
                            let columns = Array(repeating: GridItem(.flexible(), spacing: selectedPeriod == .year ? 1 : 2), count: selectedPeriod.gridColumns)
                            
                            LazyVGrid(columns: columns, spacing: selectedPeriod == .year ? 1 : 2) {
                                ForEach(dateRange, id: \.self) { date in
                                    let completionRate = getCompletionRate(for: date)
                                    
                                    Rectangle()
                                        .fill(colorForCompletion(completionRate))
                                        .frame(height: getSquareHeight())
                                        .cornerRadius(selectedPeriod == .year ? 1 : 2)
                                        .overlay(
                                            Text(getDateLabel(for: date))
                                                .font(.system(size: getFontSize()))
                                                .foregroundColor(.white.opacity(0.8))
                                                .minimumScaleFactor(0.5)
                                        )
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            // Summary stats
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(selectedPeriod.rawValue) Summary")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                let stats = getHeatMapStats()
                                
                                HStack(spacing: 12) {
                                    StatCardView(title: "Perfect Days", value: "\(stats.perfectDays)", subtitle: "100% completion")
                                    StatCardView(title: "Active Days", value: "\(stats.activeDays)", subtitle: "Any habits done")
                                }
                                
                                HStack(spacing: 12) {
                                    StatCardView(title: "Average Rate", value: "\(Int(stats.averageRate * 100))%", subtitle: "Daily completion")
                                    StatCardView(title: "Best Streak", value: "\(stats.longestStreak)", subtitle: "Consecutive days")
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func getCompletionRate(for date: Date) -> Double {
        let dailyHabits = habits.filter { habit in
            let frequency = HabitFrequency(rawValue: habit.frequency ?? "Daily") ?? .daily
            return shouldHabitBeCompletedOn(habit: habit, date: date, frequency: frequency)
        }
        
        guard !dailyHabits.isEmpty else { return 0 }
        
        let completedHabits = dailyHabits.filter { habit in
            guard let completions = habit.completions as? Set<Completion> else { return false }
            return completions.contains { completion in
                calendar.isDate(completion.date ?? Date(), inSameDayAs: date)
            }
        }
        
        return Double(completedHabits.count) / Double(dailyHabits.count)
    }
    
    private func shouldHabitBeCompletedOn(habit: Habit, date: Date, frequency: HabitFrequency) -> Bool {
        // Only count habits that existed on this date
        guard let createdDate = habit.createdDate, date >= createdDate else { return false }
        
        switch frequency {
        case .daily:
            return true
        case .weekly:
            // For weekly habits, we'll count them on all days for simplicity
            return true
        case .monthly:
            // For monthly habits, we'll count them on all days for simplicity
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return weekday != 1 && weekday != 7 // Not Sunday (1) or Saturday (7)
        }
    }
    
    private func colorForCompletion(_ rate: Double) -> Color {
        if rate == 0 {
            return Color(red: 0.15, green: 0.20, blue: 0.30) // Dark blue for no completion
        } else if rate < 0.25 {
            return Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.3) // Light blue
        } else if rate < 0.5 {
            return Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.5) // Medium light blue
        } else if rate < 0.75 {
            return Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.7) // Medium blue
        } else if rate < 1.0 {
            return Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.9) // Dark blue
        } else {
            return Color(red: 0.1, green: 0.3, blue: 0.9) // Brightest blue for 100%
        }
    }
    
    private func getHeatMapStats() -> (perfectDays: Int, activeDays: Int, averageRate: Double, longestStreak: Int) {
        var perfectDays = 0
        var activeDays = 0
        var totalRate = 0.0
        var longestStreak = 0
        var currentStreak = 0
        
        for date in dateRange {
            let rate = getCompletionRate(for: date)
            totalRate += rate
            
            if rate == 1.0 {
                perfectDays += 1
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
            
            if rate > 0 {
                activeDays += 1
            }
        }
        
        let averageRate = dateRange.isEmpty ? 0 : totalRate / Double(dateRange.count)
        
        return (perfectDays, activeDays, averageRate, longestStreak)
    }
    
    private func getSquareHeight() -> CGFloat {
        switch selectedPeriod {
        case .week: return 24
        case .month: return 18
        case .quarter: return 12
        case .year: return 10
        }
    }
    
    private func getFontSize() -> CGFloat {
        switch selectedPeriod {
        case .week: return 10
        case .month: return 8
        case .quarter: return 7
        case .year: return 6
        }
    }
    
    private func getDateLabel(for date: Date) -> String {
        let day = calendar.component(.day, from: date)
        
        switch selectedPeriod {
        case .week:
            let formatter = DateFormatter()
            formatter.dateFormat = "E" // Mon, Tue, etc.
            return formatter.string(from: date)
        case .month:
            return "\(day)" // Show day number
        case .quarter:
            return "\(day)" // Show day number
        case .year:
            return "" // No numbers for year view
        }
    }
}

// MARK: - Stat Card View
struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.14, blue: 0.22))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
static var previews: some View {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
}
