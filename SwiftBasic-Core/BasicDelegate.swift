//
//  BasicDelegate.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/8/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

/// A class that implements BasicDelegate will help a BasicParser certain tasks, like I/O.
protocol BasicDelegate {
    func handlePrintStatement(stringToPrint: String)
    
    /// Return a string; the parser will determine what type the input is.
    func handleInput() -> String
    
}
