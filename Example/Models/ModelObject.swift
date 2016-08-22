//
//  ModelObject.swift
//  Example
//
//  Created by Xin Hong on 16/7/28.
//  Copyright © 2016年 Teambition. All rights reserved.
//

import Foundation
import ObjectMapper

class ModelObject: NSObject, Mappable {
    var id: String?
    var createdAt: NSDate?
    var updatedAt: NSDate?

    required override init() { }

    required init?(_ map: Map) { }

    convenience init?(_ JSON: AnyObject) {
        self.init()
        if let JSON = JSON as? [String: AnyObject] {
            let map = Map(mappingType: .FromJSON, JSONDictionary: JSON)
            mapping(map)
        }
    }

    func mapping(map: Map) {
        id <- map["_id"]
        createdAt <- (map["created"], DateTransform())
        updatedAt <- (map["updated"], DateTransform())
    }
}

class DateTransform: DateFormatterTransform {
    init() {
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        super.init(dateFormatter: dateFormatter)
    }
}
