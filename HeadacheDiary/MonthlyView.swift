//
//  MonthlyView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI
import CoreData

struct MonthlyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    @State private var showAdd = false
    @State private var selectedRecord: HeadacheRecord?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupedRecords, id: \.month) { monthGroup in
                    Section {
                        ForEach(monthGroup.records) { record in
                            HeadacheRecordRow(record: record)
                                .onTapGesture {
                                    selectedRecord = record
                                }
                        }
                        .onDelete { offsets in
                            deleteItems(offsets: offsets, from: monthGroup.records)
                        }
                    } header: {
                        MonthHeader(
                            month: monthGroup.month,
                            count: monthGroup.records.count
                        )
                    }
                }
            }
            .navigationTitle("头痛日记")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEntryView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedRecord) { record in
                AddEntryView(editingRecord: record)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private var groupedRecords: [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            guard let timestamp = record.timestamp else {
                return calendar.dateInterval(of: .month, for: Date())!.start
            }
            return calendar.dateInterval(of: .month, for: timestamp)!.start
        }
        
        return grouped.map { (month, records) in
            MonthGroup(month: month, records: Array(records))
        }.sorted { $0.month > $1.month }
    }
    
    private func deleteItems(offsets: IndexSet, from records: [HeadacheRecord]) {
        withAnimation {
            offsets.map { records[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct MonthGroup {
    let month: Date
    let records: [HeadacheRecord]
}

struct MonthHeader: View {
    let month: Date
    let count: Int
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }
    
    private var headerColor: Color {
        switch count {
        case 0..<5:
            return .green
        case 5..<10:
            return .yellow
        case 10..<20:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        HStack {
            Text(monthFormatter.string(from: month))
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(count)次")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(headerColor)
                    .clipShape(Capsule())
                
                Circle()
                    .fill(headerColor)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MonthlyView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
