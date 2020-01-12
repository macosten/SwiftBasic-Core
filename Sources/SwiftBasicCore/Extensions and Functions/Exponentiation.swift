//
//  Exponentiation.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/11/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

// To make implementing exponentiation a bit easier, this is an exponentiation operator. It will have precedence between that of bitshifting (which is the highest) and multiplication.
precedencegroup ExponentiationPrecedence {
    associativity: right
    lowerThan: BitwiseShiftPrecedence
    higherThan: MultiplicationPrecedence
}

// ** feels less confusing than ^^, which is too reminiscent of XOR to me...
infix operator **: ExponentiationPrecedence

public func **(base: Double, exponent: Double) -> Double { pow(base, exponent) }

public func **(base: Int, exponent: Int) -> Double { pow(Double(base), Double(exponent)) }

public func **(base: Double, exponent: Int) -> Double { pow(base, Double(exponent)) }

public func **(base: Int, exponent: Double) -> Double { pow(Double(base), exponent) }


