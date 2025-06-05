import Foundation
import CoreData

@objc(HeadacheRecord)
public class HeadacheRecord: NSManagedObject {
    @NSManaged public var timestamp: Date?
    @NSManaged public var intensity: Int16
    @NSManaged public var note: String?
}
