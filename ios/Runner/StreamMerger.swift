import AVFoundation

/// Merges separate video and audio files into a single MP4 using AVFoundation.
class StreamMerger {

    static func mergeStreams(videoPath: String, audioPath: String, outputPath: String, completion: @escaping (Error?) -> Void) {
        let videoURL = URL(fileURLWithPath: videoPath)
        let audioURL = URL(fileURLWithPath: audioPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)

        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(NSError(domain: "StreamMerger", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"]))
            return
        }

        // Add audio track
        guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first,
              let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(NSError(domain: "StreamMerger", code: -2, userInfo: [NSLocalizedDescriptionKey: "No audio track found"]))
            return
        }

        do {
            let videoDuration = videoTrack.timeRange.duration
            let audioDuration = audioTrack.timeRange.duration

            try compositionVideoTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: videoDuration),
                of: videoTrack,
                at: .zero
            )

            // Use the shorter duration to avoid mismatch
            let insertDuration = CMTimeMinimum(videoDuration, audioDuration)
            try compositionAudioTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: insertDuration),
                of: audioTrack,
                at: .zero
            )
        } catch {
            completion(error)
            return
        }

        // Use passthrough export for no re-encoding
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            completion(NSError(domain: "StreamMerger", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(nil)
            case .failed:
                completion(exportSession.error ?? NSError(domain: "StreamMerger", code: -4, userInfo: [NSLocalizedDescriptionKey: "Export failed"]))
            case .cancelled:
                completion(NSError(domain: "StreamMerger", code: -5, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
            default:
                completion(NSError(domain: "StreamMerger", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unknown export status"]))
            }
        }
    }
}
