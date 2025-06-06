import SwiftUI
import CoreData

// 修改后的ContentView，包含设置页面
struct ContentView: View {
    var body: some View {
        TabView {
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
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
        }
        .onAppear {
            // 确保应用启动时通知权限已请求
            NotificationManager.shared.requestNotificationPermission()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
