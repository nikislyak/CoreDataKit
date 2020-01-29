//
//  Functional.swift
//  CoreDataKitTests
//
//  Created by Nikita Kislyakov on 29.01.2020.
//

import Foundation

func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a = a, let b = b else {
        return nil
    }
    
    return (a, b)
}

@discardableResult
func with<A: AnyObject>(_ a: A, _ configure: (A) -> Void) -> A {
    configure(a)
    
    return a
}
