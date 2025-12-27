//
//  Views/SurahListView.swift
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
                List {
                    // This acts as the subtitle directly below the Large Title
                    Section {
                        ForEach(surahs) { surah in
                            VStack(spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(surah.nameArabic)
                                            .font(.title2)

                                        Text(surah.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text(surah.revelationType)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if audioVM.currentSurah?.id == surah.id && audioVM.isPlaying {
                                        Button {
                                            audioVM.pause()
                                        } label: {
                                            Image(systemName: "pause.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                    } else if audioVM.downloadedSurahs.contains(surah.number) {
                                        HStack {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                            Button {
                                                audioVM.playSurah(surah)
                                            } label: {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title2)
                                            }
                                        }
                                    } else {
                                        HStack {
                                            Image(systemName: "cloud")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Button {
                                                audioVM.playSurah(surah)
                                            } label: {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title2)
                                            }
                                            .disabled(audioVM.isDownloading && audioVM.currentDownloadingSurah?.id == surah.id)
                                        }
                                    }

                                    if let error = audioVM.downloadError, audioVM.currentDownloadingSurah?.id == surah.id {
                                        Button("Retry") {
                                            audioVM.retryDownload(for: surah)
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    }
                                }

                                if audioVM.isDownloading && audioVM.currentDownloadingSurah?.id == surah.id {
                                    ProgressView(value: audioVM.downloadProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .padding(.horizontal)
                                }

                                if let status = audioVM.downloadStatus, audioVM.currentDownloadingSurah?.id == surah.id {
                                    Text(audioVM.isDownloading ? "Downloading…" : status)
                                        .font(.caption)
                                        .foregroundColor(status.contains("failed") ? .red : .green)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } 
                     header: {
                             Text("Recitation by Sheikh Muhammad Siddiq Al-Minshawi")
                                 .font(.subheadline)
                                 .textCase(nil) // Prevents the default uppercase style
                                 .foregroundColor(.secondary)
                         .padding(.bottom, 8)
                     }
                }
//                .listStyle(.plain)
                .navigationTitle("Al-Qur'an القرآن")
                .navigationBarTitleDisplayMode(.large)
                .safeAreaInset(edge: .bottom) {
                    PlayerBarView().environmentObject(audioVM)
                        .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut, value: audioVM.currentSurah != nil)
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
            // provide the queue to audio view model
            audioVM.setQueue(surahs)
        } catch {
            loadError = "Failed to load Quran data: \(error.localizedDescription)"
            print("Failed to load surahs.json: \(error)")
        }
    }
}
