import AVFoundation

enum StreamMergerError: LocalizedError {
    case noVideoTrack
    case noAudioTrack
    case cannotCreateCompositionTrack
    case cannotCreateExportSession
    case unsupportedOutputFileType

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "No video track found in file."
        case .noAudioTrack: return "No audio track found in file."
        case .cannotCreateCompositionTrack: return "Failed to create composition tracks."
        case .cannotCreateExportSession: return "Failed to create export session."
        case .unsupportedOutputFileType: return "MP4 is not supported for this export configuration."
        }
    }
}

/// Merges separate video and audio files into a single MP4 using AVFoundation.
final class StreamMerger {

    /// Callback-based entry point (called from Flutter platform channel).
    static func mergeStreams(
        videoPath: String,
        audioPath: String,
        outputPath: String,
        completion: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await mergeStreams(videoPath: videoPath, audioPath: audioPath, outputPath: outputPath)
                await MainActor.run { completion(nil) }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }

    /// Async implementation using modern AVFoundation APIs.
    static func mergeStreams(
        videoPath: String,
        audioPath: String,
        outputPath: String
    ) async throws {
        let videoURL = URL(fileURLWithPath: videoPath)
        let audioURL = URL(fileURLWithPath: audioPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        try? FileManager.default.removeItem(at: outputURL)

        // MIME type hints for .m4s (fragmented MP4) files
        let videoAsset = AVURLAsset(url: videoURL, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
            AVURLAssetOverrideMIMETypeKey: "video/mp4"
        ])

        let audioAsset = AVURLAsset(url: audioURL, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
            AVURLAssetOverrideMIMETypeKey: "audio/mp4"
        ])

        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first else {
            throw StreamMergerError.noVideoTrack
        }

        guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw StreamMergerError.noAudioTrack
        }

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)

        let composition = AVMutableComposition()

        guard
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw StreamMergerError.cannotCreateCompositionTrack
        }

        // Preserve original video orientation/rotation
        compositionVideoTrack.preferredTransform = try await videoTrack.load(.preferredTransform)

        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )

        let audioInsertDuration = CMTimeMinimum(videoDuration, audioDuration)
        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: audioInsertDuration),
            of: audioTrack,
            at: .zero
        )

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw StreamMergerError.cannotCreateExportSession
        }

        // Verify .mp4 is supported before attempting export
        guard exportSession.supportedFileTypes.contains(.mp4) else {
            throw StreamMergerError.unsupportedOutputFileType
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? StreamMergerError.cannotCreateExportSession)
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    continuation.resume(throwing: exportSession.error ?? StreamMergerError.cannotCreateExportSession)
                }
            }
        }
    }
}
