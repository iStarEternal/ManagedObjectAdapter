//
//  ManagedObjectAdapter.swift
//  ManagedObjectAdapter
//
//  Created by Xin Hong on 16/7/27.
//  Copyright © 2016年 Teambition. All rights reserved.
//

import Foundation
import CoreData

public extension ManagedObjectSerializing {
    public static func modelFromManagedObject(managedObject: NSManagedObject) -> Self? {
        let propertyKeys = self.propertyKeys
        let managedObjectKeys = generateManagedObjectKeysByPropertyKey()
        let valueTransformers = valueTransformersByPropertyKey()

        for (_, propertyKey) in managedObjectKeys {
            if propertyKeys.contains(propertyKey) {
                continue
            }
            return nil
        }

        let model = self.init()
        let managedObjectPropertyDescriptions = managedObject.entity.propertiesByName

        for propertyKey in propertyKeys {
            guard let managedObjectKey = managedObjectKeys[propertyKey] else {
                continue
            }
            guard let propertyDescription = managedObjectPropertyDescriptions[managedObjectKey] else {
                continue
            }

            var value: AnyObject?
            managedObject.managedObjectContext?.performBlockAndWait({
                value = managedObject.valueForKey(managedObjectKey)
            })

            switch propertyDescription {
            case is NSAttributeDescription:
                if let valueTransformer = valueTransformers[propertyKey] {
                    let transformedValue = valueTransformer.reverseTransformedValue(value)
                    model.setValue(transformedValue, forKey: managedObjectKey)
                } else {
                    model.setValue(value, forKey: managedObjectKey)
                }
            case is NSRelationshipDescription:
                guard let nestedClass = relationshipModelClassesByPropertyKey()[propertyKey] else {
                    break
                }
                let relationshipDescription = propertyDescription as! NSRelationshipDescription

                if relationshipDescription.toMany {
                    var models: [AnyObject]?
                    managedObject.managedObjectContext?.performBlockAndWait({
                        let relationshipCollection = managedObject.valueForKey(managedObjectKey)
                        if let valueEnumerator = relationshipCollection?.objectEnumerator() {
                            models = valueEnumerator.allObjects.flatMap({ (object) -> AnyObject? in
                                if let nestedManagedObject = object as? NSManagedObject, nestedClass = nestedClass as? ManagedObjectSerializing.Type {
                                    return nestedClass.modelFromManagedObject(nestedManagedObject)
                                }
                                return nil
                            })
                        }
                    })

                    if !relationshipDescription.ordered {
                        let modelsSet: NSSet? = {
                            if let models = models {
                                return NSSet(array: models)
                            }
                            return nil
                        }()
                        model.setValue(modelsSet, forKey: propertyKey)
                    } else {
                        model.setValue(models, forKey: propertyKey)
                    }
                } else {
                    if let nestedManagedObject = value as? NSManagedObject, nestedClass = nestedClass as? ManagedObjectSerializing.Type {
                        let nestedObject = nestedClass.modelFromManagedObject(nestedManagedObject)
                        model.setValue(nestedObject, forKey: propertyKey)
                    }
                }
            default:
                break
            }
        }

        return model
    }

    public func toManagedObject(context: NSManagedObjectContext) -> NSManagedObject? {
        let entityName = self.dynamicType.managedObjectEntityName()
        let valueTransformers = self.dynamicType.valueTransformersByPropertyKey()
        let managedObjectKeys = self.dynamicType.generateManagedObjectKeysByPropertyKey()

        var managedObject: NSManagedObject?

        if let uniquingPredicate = generateUniquingPredicate() {
            context.performBlockAndWait({
                let fetchRequest = NSFetchRequest()
                fetchRequest.entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext: context)
                fetchRequest.predicate = uniquingPredicate
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.fetchLimit = 1

                let results = try? context.executeFetchRequest(fetchRequest)
                if let object = results?.first as? NSManagedObject {
                    managedObject = object
                }
            })
        }

        if let _ = managedObject {

        } else {
            managedObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: context)
        }

        let managedObjectPropertyDescriptions = managedObject!.entity.propertiesByName

        for propertyKey in propertyKeys {
            guard let managedObjectKey = managedObjectKeys[propertyKey] else {
                continue
            }
            guard let propertyDescription = managedObjectPropertyDescriptions[managedObjectKey] else {
                continue
            }

            let value = valueForKey(propertyKey)

            switch propertyDescription {
            case is NSAttributeDescription:
                if let valueTransformer = valueTransformers[propertyKey] {
                    let transformedValue = valueTransformer.transformedValue(value)
                    managedObject?.setValue(transformedValue, forKey: managedObjectKey)
                } else {
                    managedObject?.setValue(value, forKey: managedObjectKey)
                }
            case is NSRelationshipDescription:
                let relationshipDescription = propertyDescription as! NSRelationshipDescription

                if relationshipDescription.toMany {
                    if let valueEnumerator = value?.objectEnumerator() {
                        let relationshipCollection = relationshipDescription.ordered ? NSMutableOrderedSet() : NSMutableSet()

                        for nestedValue in valueEnumerator.allObjects {
                            if let nestedObject = nestedValue as? ManagedObjectSerializing, nestedManagedObject = nestedObject.toManagedObject(context) {
                                switch relationshipCollection {
                                case is NSMutableOrderedSet:
                                    (relationshipCollection as! NSMutableOrderedSet).addObject(nestedManagedObject)
                                case is NSMutableSet:
                                    (relationshipCollection as! NSMutableSet).addObject(nestedManagedObject)
                                default:
                                    break
                                }
                            }
                        }

                        managedObject?.setValue(relationshipCollection, forKey: managedObjectKey)
                    }
                } else {
                    if let nestedObject = value as? ManagedObjectSerializing, nestedManagedObject = nestedObject.toManagedObject(context) {
                        managedObject?.setValue(nestedManagedObject, forKey: managedObjectKey)
                    }
                }
            default:
                break
            }
        }

        return managedObject
    }
}

internal extension ManagedObjectSerializing {
    internal static func generateManagedObjectKeysByPropertyKey() -> [String: String] {
        var managedObjectKeys = [String: String]()
        for property in propertyKeys {
            managedObjectKeys.updateValue(property, forKey: property)
        }

        for (managedObjectKey, propertyKey) in managedObjectKeysByPropertyKey() {
            managedObjectKeys.updateValue(propertyKey, forKey: managedObjectKey)
        }

        return managedObjectKeys
    }

    internal func generateUniquingPredicate() -> NSPredicate? {
        let uniquingPropertyKeys = self.dynamicType.propertyKeysForManagedObjectUniquing()
        let valueTransformers = self.dynamicType.valueTransformersByPropertyKey()
        let managedObjectKeys = self.dynamicType.generateManagedObjectKeysByPropertyKey()

        guard uniquingPropertyKeys.count > 0 else {
            return nil
        }

        var subpredicates = [NSPredicate]()
        for uniquingPropertyKey in uniquingPropertyKeys {
            guard let managedObjectKey = managedObjectKeys[uniquingPropertyKey] else {
                continue
            }

            var value = valueForKey(uniquingPropertyKey)
            if let transformer = valueTransformers[uniquingPropertyKey] {
                value = transformer.transformedValue(value)
            }

            if let value = value as? NSObject {
                let subpredicate = NSPredicate(format: "%K == %@", managedObjectKey, value)
                subpredicates.append(subpredicate)
            }
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }
}
