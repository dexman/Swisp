//
//  utilities.swift
//  Swisp
//
//  Created by Arthur Dexter on 10/25/16.
//  Copyright © 2016 LivingSocial. All rights reserved.
//

import Foundation

extension Dictionary {

    init(keys: [Key], values: [Value]) {
        self = zip(keys, values).reduce([:]) {
            var r = $0; r[$1.0] = $1.1; return r
        }
    }

}
