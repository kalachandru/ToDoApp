import SwiftUI
import SwiftData

// MARK: - Task Model
@Model
class TodoTask {
    var title: String
    var taskDescription: String
    var dueDate: Date
    var priorityRaw: Int      // stored for sorting
    var isCompletedRaw: Int   // stored for sorting
    var createdAt: Date
    
    // Convenience computed props
    var isCompleted: Bool {
        get { isCompletedRaw == 1 }
        set { isCompletedRaw = newValue ? 1 : 0 }
    }
    
    var priority: Priority {
        get { Priority.allCases[priorityRaw] }
        set { priorityRaw = newValue.sortOrder }
    }

    init(title: String, description: String = "", dueDate: Date = Date(), priority: Priority = .medium) {
        self.title = title
        self.taskDescription = description
        self.dueDate = dueDate
        self.priorityRaw = priority.sortOrder
        self.isCompletedRaw = 0   // default not completed
        self.createdAt = Date()
    }
}




// MARK: - Priority Enum
enum Priority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }
}

// MARK: - Main App
@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentViews()
        }
        .modelContainer(for: TodoTask.self)
    }
}

// MARK: - Content View
struct ContentViews: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\TodoTask.isCompletedRaw, order: .forward),
        SortDescriptor(\TodoTask.priorityRaw, order: .forward),
        SortDescriptor(\TodoTask.dueDate, order: .forward)
    ]) private var tasks: [TodoTask]
    
    @State private var showingAddTask = false
    @State private var taskToDelete: TodoTask?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if tasks.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(tasks, id: \.self) { task in
                            TaskRowView(task: task) {
                                toggleTaskCompletion(task)
                            }
                        }
                        .onDelete(perform: requestDelete)
                    }
                }
            }
            .navigationTitle("Todo List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .alert("Delete Task", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
        }
    }
    
    private func toggleTaskCompletion(_ task: TodoTask) {
        withAnimation {
            task.isCompleted.toggle()
        }
    }
    
    private func requestDelete(offsets: IndexSet) {
        if let index = offsets.first {
            taskToDelete = tasks[index]
            showingDeleteAlert = true
        }
    }
    
    private func deleteTask(_ task: TodoTask) {
        withAnimation {
            modelContext.delete(task)
        }
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    let task: TodoTask
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .gray : .primary)
                    
                    Spacer()
                    
                    PriorityBadge(priority: task.priority)
                }
                
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(task.dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(task.dueDate < Date() && !task.isCompleted ? .red : .secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(task.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: Priority
    
    var body: some View {
        Text(priority.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.2))
            .foregroundColor(priority.color)
            .cornerRadius(8)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Tasks Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Tap the + button to add your first task")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Add Task View
struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var selectedPriority = Priority.medium
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Due Date")) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            HStack {
                                Text(priority.rawValue)
                                Spacer()
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 12, height: 12)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveTask() {
        let newTask = TodoTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            priority: selectedPriority
        )
        
        modelContext.insert(newTask)
        dismiss()
    }
}

#Preview {
    ContentViews()
}
