//
//  File.swift
//  
//
//  Created by Zaccari Silverman on 3/8/20.
//

import Foundation

/// This struct holds the data related to a for loop.
struct LoopEntry { // for i in (Range)
    let indexName: String // The name of the variable we're incrementing. It'll always be an integer.
    let range: Range<Int> // The range in which the index operates (not including the upper bound).
    let startLine: Int // Line number of the first line of the loop.
}
