import Foundation

enum MedicineType: String, CaseIterable {
    case tylenol = "tylenol"
    case ibuprofen = "ibuprofen"
    
    var displayName: String {
        switch self {
        case .tylenol:
            return "泰诺"
        case .ibuprofen:
            return "布洛芬"
        }
    }
}

enum HeadacheLocation: String, CaseIterable {
    case forehead = "forehead"
    case leftSide = "leftSide"
    case rightSide = "rightSide"
    case temple = "temple"
    case face = "face"
    
    var displayName: String {
        switch self {
        case .forehead:
            return "额头"
        case .leftSide:
            return "左侧"
        case .rightSide:
            return "右侧"
        case .temple:
            return "太阳穴"
        case .face:
            return "面部"
        }
    }
}
