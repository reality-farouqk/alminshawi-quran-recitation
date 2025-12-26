//
//  SurahListView.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import SwiftUI

struct SurahListView: View {
    @State private var surahs: [Surah] = []
    @State private var loadError: String?
    @StateObject private var audioVM = AudioPlayerViewModel()

    var body: some View {
        NavigationStack {
            if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error Loading Quran Data")
                        .font(.headline)
                        .padding()
                    Text(error)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadSurahs()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if surahs.isEmpty {
                ProgressView("Loading Quran...")
            } else {
                List(surahs) { surah in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(surah.nameArabic)
                                .font(.title2)

                            Text(surah.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            audioVM.playSurah(surah)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .navigationTitle("Al-Qur'an")
                .safeAreaInset(edge: .bottom) {
                    PlayerBarView().environmentObject(audioVM)
                }
            }
        }
        .onAppear(perform: loadSurahs)
    }

    private func loadSurahs() {
        loadError = nil // Clear previous errors
        guard let url = Bundle.main.url(forResource: "surahs", withExtension: "json") else {
            loadError = "Quran data file not found. Please ensure the app is properly installed."
            print("surahs.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            surahs = try decoder.decode([Surah].self, from: data)
        } catch {
            loadError = "Failed to load Quran data: \(error.localizedDescription)"
            print("Failed to load surahs.json: \(error)")
        }
    }
}

