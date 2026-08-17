//
//  Int+Digits.swift
//  Gita
//

import Foundation

nonisolated extension Int {
    /// The number in whichever script is being read.
    ///
    /// `isDevanagari ? n.devanagariDigits : "\(n)"` was written out at nine
    /// call sites; the paired form below had already drifted, one site spacing
    /// the slash and the others not.
    func digits(devanagari: Bool) -> String {
        devanagari ? devanagariDigits : String(self)
    }

    /// "12/47" — a count against a total, in one script.
    static func ratio(
        _ value: Int, of total: Int, devanagari: Bool, separator: String = "/"
    ) -> String {
        value.digits(devanagari: devanagari)
            + separator
            + total.digits(devanagari: devanagari)
    }

    /// The number written in Devanagari digits: ०१२३४५६७८९.
    ///
    /// Reading "47 श्लोक" in a Devanagari list is the same jar as an English
    /// subtitle under a Sanskrit name — the script should hold all the way
    /// through, numerals included.
    var devanagariDigits: String {
        String(String(self).map { character in
            guard let value = character.wholeNumberValue, (0 ... 9).contains(value) else {
                return character
            }
            return Character(UnicodeScalar(0x0966 + value)!)
        })
    }
}
