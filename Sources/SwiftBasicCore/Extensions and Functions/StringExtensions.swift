//
//  File.swift
//  
//
//  Created by Zaccari Silverman on 1/21/20.
//

import Foundation

extension String {
    
    /// Checks if the first and last characters are matching quotes.
    var isQuotation : Bool {
        let prefix = self.prefix(1)
        let suffix = self.suffix(1)
        if prefix == "\"" && suffix == "\""
        || prefix == "“"  && suffix == "”"
        || prefix == "«"  && suffix == "»"
        || prefix == "「"  && suffix == "」"
        { return true }
        else { return false }
    }
}
