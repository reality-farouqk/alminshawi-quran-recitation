//
//  SurahDetailView.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by GitHub Copilot on 12/25/2025.
//

import SwiftUI

struct SurahDetailView: View {
    let surah: Surah
    @EnvironmentObject var audioVM: AudioPlayerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(surah.nameArabic)
                .font(.largeTitle)

            Text(surah.displayName)
                .font(.title3)
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                Button {
                    audioVM.playSurah(surah)
                } label: {
                    Label("Play", systemImage: "play.fill")
                }

                Button {
                    audioVM.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle(surah.displayName)
    }
}

struct SurahDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = Surah(id: 1, nameSimple: "Al-Fatiha", nameArabic: "الفاتحة", ayahCount: 7, englishName: "The Opening", revelationType: "Meccan")
        SurahDetailView(surah: sample)
            .environmentObject(AudioPlayerViewModel())
    }
}
