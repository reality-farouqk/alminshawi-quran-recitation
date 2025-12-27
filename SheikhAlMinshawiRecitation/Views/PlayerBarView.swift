//
//  Views/PlayerBarView.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import SwiftUI

struct PlayerBarView: View {
@EnvironmentObject var audioVM: AudioPlayerViewModel


var body: some View {
	VStack(spacing: 8) {
		if audioVM.errorMessage != nil {
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
		} else if let error = audioVM.downloadError {
			HStack {
				Image(systemName: "exclamationmark.triangle")
					.foregroundColor(.red)
				Text(error.localizedDescription)
					.font(.caption)
					.foregroundColor(.red)
				Spacer()
				Button(action: {
					// Allow clearing download error
					audioVM.downloadError = nil
				}) {
					Image(systemName: "xmark")
						.foregroundColor(.gray)
				}
			}
			.padding(.horizontal)
		} else if let surah = audioVM.currentSurah {
			VStack(alignment: .center, spacing: 16) {
				VStack(alignment: .center) {
					Text(surah.nameSimple)
						.font(.title)
						.bold()
					Text(surah.englishName)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				HStack(spacing: 24) {
					Button(action: { audioVM.toggleShuffle() }) {
						Image(systemName: audioVM.shuffle ? "shuffle.circle.fill" : "shuffle.circle")
							.font(.title)
							.foregroundColor(audioVM.shuffle ? .blue : .primary)
					}

					Button(action: { audioVM.previousSurah() }) {
						Image(systemName: "backward.fill")
							.font(.title)
					}

					Button(action: {
						audioVM.isPlaying ? audioVM.pause() : audioVM.play()
					}) {
						Image(systemName: audioVM.isPlaying ? "pause.fill" : "play.fill")
							.font(.largeTitle)
					}

					Button(action: { audioVM.nextSurah() }) {
						Image(systemName: "forward.fill")
							.font(.title)
					}

					Button(action: { audioVM.cycleRepeatMode() }) {
						Image(systemName: audioVM.repeatMode == .one ? "repeat.1.circle.fill" : audioVM.repeatMode == .all ? "repeat.circle.fill" : "repeat.circle")
							.font(.title)
							.foregroundColor(audioVM.repeatMode != .off ? .blue : .primary)
					}
				}

				Slider(value: Binding(get: { audioVM.progress }, set: { newVal in
					audioVM.seek(to: newVal)
				}), in: 0...(audioVM.duration > 0 ? audioVM.duration : 1))

				// Duration display
				HStack {
					Text(formatTime(audioVM.progress))
						.font(.caption)
						.foregroundColor(.secondary)
					Spacer()
					Text(formatTime(audioVM.duration))
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		} else {
			HStack {
				Text("Not playing, click to play").font(.subheadline)
				Spacer()
			}
		}
	}
	.padding(.horizontal)
	.padding(.top, 16)
	.background(Color(UIColor.systemBackground).opacity(0.85))
}

private func formatTime(_ time: Double) -> String {
    let hours = Int(time) / 3600
    let minutes = (Int(time) % 3600) / 60
    let seconds = Int(time) % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}
}
