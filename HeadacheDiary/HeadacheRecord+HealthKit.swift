import Foundation
import CoreData
import HealthKit

// MARK: - HeadacheRecord HealthKit 扩展
extension HeadacheRecord {
    
    /// 自动同步头痛记录到 HealthKit
    func syncToHealthKit() async {
        guard let _ = self.timestamp else {
            print("⚠️ 头痛记录缺少时间戳，跳过HealthKit同步")
            return
        }
        
        let success = await HealthKitManager.shared.syncHeadacheToHealthKit(self)
        if success {
            print("✅ 头痛记录已同步到HealthKit: \(self.objectID)")
        } else {
            print("❌ 头痛记录同步到HealthKit失败: \(self.objectID)")
        }
    }
    
    /// 获取记录创建时的健康数据快照（用于相关性分析）
    func captureHealthSnapshot() async {
        guard HealthKitManager.shared.isAuthorized else {
            print("⚠️ HealthKit未授权，跳过健康数据快照")
            return
        }
        
        // 获取记录时间点前后的健康数据
        await HealthKitManager.shared.fetchRecentHealthData(days: 1)
        
        // 触发相关性分析更新
        Task {
            await HealthAnalysisEngine.shared.performCorrelationAnalysis()
        }
    }
}

// MARK: - Core Data 保存时自动触发 HealthKit 同步
extension NSManagedObjectContext {
    
    /// 自动处理HealthKit同步的保存方法
    func saveWithHealthKitSync() throws {
        // 获取即将保存的HeadacheRecord对象
        let insertedHeadacheRecords = self.insertedObjects.compactMap { $0 as? HeadacheRecord }
        let updatedHeadacheRecords = self.updatedObjects.compactMap { $0 as? HeadacheRecord }
        
        // 先执行原有的保存操作
        try self.save()
        
        // 异步处理HealthKit同步和健康数据分析
        for record in insertedHeadacheRecords + updatedHeadacheRecords {
            Task {
                // 同步到HealthKit
                await record.syncToHealthKit()
                
                // 捕获健康数据快照用于分析
                await record.captureHealthSnapshot()
            }
        }
        
        print("✅ Core Data保存完成，已启动HealthKit同步和健康分析")
    }
}