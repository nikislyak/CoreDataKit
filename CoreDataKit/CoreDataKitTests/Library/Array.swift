//
//  Array.swift
//  CoreDataKitTests
//
//  Created by Nikita Kislyakov on 30.01.2020.
//  Copyright © 2020 Nikita Kislyakov. All rights reserved.
//

import Foundation

extension Collection {
    func sorted<V: Comparable>(by keyPath: KeyPath<Element, V>, increasingOrder: Bool = true) -> [Element] {
        sorted {
            if increasingOrder {
                return $0[keyPath: keyPath] < $1[keyPath: keyPath]
            } else {
                return $0[keyPath: keyPath] > $1[keyPath: keyPath]
            }
        }
    }
}
