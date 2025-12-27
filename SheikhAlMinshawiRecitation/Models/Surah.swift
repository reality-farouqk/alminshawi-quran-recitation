//
//  models/Surah.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import Foundation


struct Surah: Identifiable, Codable {
    let id: Int              // ✅ Surah number (1–114)
    let nameSimple: String
    let nameArabic: String
    let englishName: String
    let revelationType: String
    let ayahCount: Int

    var number: Int { id }   // computed property for backward compatibility

    // useful computed properties
    var displayName: String { "\(id). \(nameSimple)" }
}
