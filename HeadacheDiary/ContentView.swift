import SwiftUI
import CoreData

// 完整的ContentView，包含所有必要组件
struct ContentView: View {
    var body: some View {
        TabView {
            ListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("列表")
                }
            
            MonthlyView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("月份")
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("统计")
                }
        }
    }
}

// ListView组件
struct ListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HeadacheRecord.timestamp, ascending: false)],
        animation: .default)
    private var records: FetchedResults<HeadacheRecord>
    
    @State private var showAdd = false
    @State private var selectedRecord: HeadacheRecord?
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(records, id: \.objectID) { record in
                    HeadacheRecordRow(record: record)
                        .onTapGesture {
                            selectedRecord = record
                        }
                }
                .onDelete(perform: deleteItems)
            }
            .refreshable {
                refreshID = UUID()
                viewContext.refreshAllObjects()
            }
            .navigationTitle("全部记录")
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
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            refreshID = UUID()
                            viewContext.refreshAllObjects()
                        }
                    }
            }
            .sheet(item: $selectedRecord) { record in
                AddEntryView(editingRecord: record)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            refreshID = UUID()
                            viewContext.refreshAllObjects()
                        }
                        selectedRecord = nil
                    }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { records[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
                refreshID = UUID()
            } catch {
                let nsError = error as NSError
                print("删除失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
