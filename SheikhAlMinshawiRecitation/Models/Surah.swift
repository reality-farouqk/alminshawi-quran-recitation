//
//  Surah.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import Foundation


struct Surah: Identifiable, Codable {
let id: Int // surah number
let nameSimple: String
let nameArabic: String
let ayahCount: Int
let englishName: String
let revelationType: String


// useful computed properties
var displayName: String { "\(id). \(nameSimple)" }
}
