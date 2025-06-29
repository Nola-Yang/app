//
//  Entity+CoreDataProperties.swift
//  
//
//  Created by 俟岳安 on 2025-06-29.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Entity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }


}

extension Entity : Identifiable {

}
