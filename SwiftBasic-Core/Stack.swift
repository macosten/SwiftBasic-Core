//
//  Stack.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

/// A stack for the Basic runtime.
struct Stack<T> {
    private var memory = [T]()
    
    mutating func push(_ input: T){ memory.append(input) }
    mutating func pop() -> T? { memory.popLast() }
    func peek() -> T? { memory.last }
    
}
