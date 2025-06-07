import SwiftUI
import CoreData

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
            
            // 天气分析页面
            WeatherAnalysisView()
                .tabItem {
                    Image(systemName: "cloud.sun.bolt")
                    Text("天气")
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
            
            // 初始化天气服务
            WeatherService.shared.requestCurrentLocationWeather()
        }
        
        
        
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
