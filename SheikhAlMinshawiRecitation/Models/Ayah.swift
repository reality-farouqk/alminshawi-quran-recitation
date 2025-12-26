//
//  Ayah.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import Foundation


struct Ayah: Identifiable {
let id: Int // ayah index (1-based)
let text: String?
let audioFileName: String // e.g. "sura_2_255.mp3" or path
}
