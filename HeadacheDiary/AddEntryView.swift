import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var timestamp: Date = Date()
    @State private var intensity: Double = 5
    @State private var note: String = ""

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                VStack(alignment: .leading) {
                    Text("Intensity: \(Int(intensity))")
                    Slider(value: $intensity, in: 1...10, step: 1)
                }
                TextField("Note", text: $note, axis: .vertical)
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let record = HeadacheRecord(context: viewContext)
        record.timestamp = timestamp
        record.intensity = Int16(intensity)
        record.note = note.isEmpty ? nil : note
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save record: \(error)")
        }
    }
}

#Preview {
    AddEntryView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
