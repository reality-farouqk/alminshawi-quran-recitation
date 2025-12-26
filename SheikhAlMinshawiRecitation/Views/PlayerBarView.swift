//
//  PlayerBarView.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import SwiftUI

struct PlayerBarView: View {
@EnvironmentObject var audioVM: AudioPlayerViewModel


var body: some View {
VStack(spacing: 8) {
if let error = audioVM.errorMessage {
HStack {
Image(systemName: "exclamationmark.triangle")
.foregroundColor(.red)
Text("Error")
.font(.subheadline)
.bold()
.foregroundColor(.red)
Spacer()
Button(action: {
audioVM.clearError()
}) {
Image(systemName: "xmark")
.foregroundColor(.gray)
}
}
.padding(.horizontal)
} else if let surah = audioVM.currentSurah {
			HStack {
				Text(surah.nameSimple)
					.font(.subheadline)
					.bold()
				Spacer()
				HStack(spacing: 16) {
					Button(action: {
						audioVM.isPlaying ? audioVM.pause() : audioVM.play()
					}) {
						Image(systemName: audioVM.isPlaying ? "pause.fill" : "play.fill")
							.font(.title2)
					}
				}
			}
Slider(value: Binding(get: { audioVM.progress }, set: { newVal in
audioVM.seek(to: newVal)
}), in: 0...(audioVM.duration > 0 ? audioVM.duration : 1))
} else {
HStack {
Text("Not playing").font(.subheadline)
Spacer()
}
}
}
.padding(.horizontal)
.padding(.top, 6)
.background(Color(UIColor.systemBackground).opacity(0.95))
}
}
