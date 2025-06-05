//
//  HeadRecoder.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//


import Foundation
import CoreData

@objc(HeadacheRecord)
public class HeadacheRecord: NSManagedObject {

}

extension HeadacheRecord: Identifiable {
    public var id: NSManagedObjectID {
        return self.objectID
    }
}
