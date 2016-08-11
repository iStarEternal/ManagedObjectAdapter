//
//  OrignizationTransformer.swift
//  Example
//
//  Created by Xin Hong on 16/8/10.
//  Copyright © 2016年 Teambition. All rights reserved.
//

import UIKit
import ObjectMapper

class OrignizationTransformer: NSValueTransformer {
    override func transformedValue(value: AnyObject?) -> AnyObject? {
        if let object = value as? Organization {
            let json = Mapper().toJSON(object)
            return NSKeyedArchiver.archivedDataWithRootObject(json)
        }
        return nil
    }

    override func reverseTransformedValue(value: AnyObject?) -> AnyObject? {
        if let data = value as? NSData {
            let json = NSKeyedUnarchiver.unarchiveObjectWithData(data)
            return Mapper<Organization>().map(json)
        }
        return nil
    }
}