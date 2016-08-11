//
//  ManagedObjectSerializing.swift
//  ManagedObjectAdapter
//
//  Created by Xin Hong on 16/7/27.
//  Copyright © 2016年 Teambition. All rights reserved.
//

import Foundation

public protocol ManagedObjectSerializing: AnyObject {
    init()
    func valueForKey(key: String) -> AnyObject?
    func setValue(value: AnyObject?, forKey key: String)

    static func managedObjectEntityName() -> String
    static func managedObjectKeysByPropertyKey() -> [String: String]
    static func valueTransformersByPropertyKey() -> [String: NSValueTransformer]
    static func relationshipModelClassesByPropertyKey() -> [String: AnyClass]
    static func propertyKeysForManagedObjectUniquing() -> Set<String>
}

public extension ManagedObjectSerializing {
    static func managedObjectEntityName() -> String {
        return String(self)
    }

    static func managedObjectKeysByPropertyKey() -> [String: String] {
        return [:]
    }

    static func valueTransformersByPropertyKey() -> [String: NSValueTransformer] {
        return [:]
    }

    static func relationshipModelClassesByPropertyKey() -> [String: AnyClass] {
        return [:]
    }

    static func propertyKeysForManagedObjectUniquing() -> Set<String> {
        return []
    }
}

public extension ManagedObjectSerializing {
    public static var propertyKeys: Set<String> {
        if let cachedKeys = objc_getAssociatedObject(self, &AssociatedKeys.cachedPropertyKeys) as? Set<String> {
            return cachedKeys
        }
        let keys = self.init().propertyKeys
        objc_setAssociatedObject(self, &AssociatedKeys.cachedPropertyKeys, keys, .OBJC_ASSOCIATION_COPY)
        return keys
    }

    public var propertyKeys: Set<String> {
        var keys = [String]()
        var currentMirror = Mirror(reflecting: self)
        while true {
            keys.appendContentsOf(currentMirror.children.flatMap { $0.label })
            if let superMirror = currentMirror.superclassMirror() {
                currentMirror = superMirror
            } else {
                break
            }
        }
        return Set(keys)
    }
}