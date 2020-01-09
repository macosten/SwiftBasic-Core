//
//  LabelMap.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/8/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

/// Stores labels (integers and identifiers) and maps them to an integer value for the program counter to jump to.
struct LabelMap {
    
    private var intDict = [Int: Int]() // Maps integer labels to an integer value for the program counter.
    private var identifierDict = [String: Int]() // Maps identifiers to an integer value for the program counter.
    
    var count : Int { intDict.count + identifierDict.count }
    
    mutating func insert(intLabel: Int, value: Int?){ intDict[intLabel] = value }
    mutating func insert(identifierLabel: String, value: Int?){ identifierDict[identifierLabel] = value }
    
    func valueFor(intLabel: Int) -> Int? { intDict[intLabel] }
    func valueFor(identifierLabel: String) -> Int? {  identifierDict[identifierLabel] }
    
    subscript(index: Int) -> Int? {
        get { valueFor(intLabel: index) }
        set(newValue){ insert(intLabel: index, value: newValue) }
    }
    
    subscript(index: String) -> Int? {
        get { valueFor(identifierLabel: index) }
        set(newValue){ insert(identifierLabel: index, value: newValue) }
    }
    
    mutating func removeAll() {
        intDict.removeAll()
        identifierDict.removeAll()
    }
}
