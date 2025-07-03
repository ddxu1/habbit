import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)],
        animation: .default)
    private var habits: FetchedResults<Habit>
    
    @State private var showingAddHabit = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(habits) { habit in
                    HabitRowView(habit: habit)
                }
                .onDelete(perform: deleteHabits)
            }
            .navigationTitle("Habits")
            .toolbar {
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
    
    private var isCompletedToday: Bool {
        guard let completions = habit.completions as? Set<Completion> else { return false }
        return completions.contains { completion in
            Calendar.current.isDateInToday(completion.date ?? Date())
        }
    }
    
    private var currentStreak: Int {
        guard let completions = habit.completions as? Set<Completion> else { return 0 }
        let sortedDates = completions.compactMap { $0.date }.sorted(by: >)
        
        var streak = 0
        var currentDate = Date()
        
        for date in sortedDates {
            if Calendar.current.isDate(date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
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
                    Text("🔥 \(currentStreak) day streak")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("Created \(habit.createdDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Habit Name", text: $habitName)
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
    
    private func saveHabit() {
        let newHabit = Habit(context: viewContext)
        newHabit.name = habitName.trimmingCharacters(in: .whitespaces)
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
