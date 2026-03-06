import AVFoundation

/// Merges separate video and audio files into a single MP4 using AVFoundation.
final class StreamMerger {

    static func mergeStreams(
        videoPath: String,
        audioPath: String,
        outputPath: String,
        completion: @escaping (Error?) -> Void
    ) {
        let videoURL = URL(fileURLWithPath: videoPath)
        let audioURL = URL(fileURLWithPath: audioPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        try? FileManager.default.removeItem(at: outputURL)

        let videoAsset = makeAsset(url: videoURL, mimeType: "video/mp4")
        let audioAsset = makeAsset(url: audioURL, mimeType: "audio/mp4")

        let keys = ["tracks", "duration"]

        videoAsset.loadValuesAsynchronously(forKeys: keys) {
            if let error = validate(asset: videoAsset, keys: keys) {
                finish(completion, error)
                return
            }

            audioAsset.loadValuesAsynchronously(forKeys: keys) {
                if let error = validate(asset: audioAsset, keys: keys) {
                    finish(completion, error)
                    return
                }

                guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
                    finish(completion, NSError(
                        domain: "StreamMerger", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "No video track found in file"]
                    ))
                    return
                }

                guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
                    finish(completion, NSError(
                        domain: "StreamMerger", code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "No audio track found in file"]
                    ))
                    return
                }

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
                    finish(completion, NSError(
                        domain: "StreamMerger", code: -5,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create composition tracks"]
                    ))
                    return
                }

                do {
                    let videoDuration = videoAsset.duration
                    let audioDuration = audioAsset.duration
                    let insertDuration = CMTimeMinimum(videoDuration, audioDuration)

                    // Preserve video orientation
                    compositionVideoTrack.preferredTransform = videoTrack.preferredTransform

                    try compositionVideoTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: videoDuration),
                        of: videoTrack,
                        at: .zero
                    )

                    try compositionAudioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: insertDuration),
                        of: audioTrack,
                        at: .zero
                    )

                    guard let exportSession = AVAssetExportSession(
                        asset: composition,
                        presetName: AVAssetExportPresetPassthrough
                    ) else {
                        finish(completion, NSError(
                            domain: "StreamMerger", code: -6,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]
                        ))
                        return
                    }

                    exportSession.outputURL = outputURL
                    exportSession.shouldOptimizeForNetworkUse = false

                    // Check mp4 compatibility; fallback to m4v
                    if exportSession.supportedFileTypes.contains(.mp4) {
                        exportSession.outputFileType = .mp4
                    } else if exportSession.supportedFileTypes.contains(.m4v) {
                        exportSession.outputFileType = .m4v
                    } else {
                        finish(completion, NSError(
                            domain: "StreamMerger", code: -7,
                            userInfo: [NSLocalizedDescriptionKey: "No compatible output file type found"]
                        ))
                        return
                    }

                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            finish(completion, nil)
                        case .failed:
                            finish(completion, exportSession.error ?? NSError(
                                domain: "StreamMerger", code: -8,
                                userInfo: [NSLocalizedDescriptionKey: "Export failed"]
                            ))
                        case .cancelled:
                            finish(completion, NSError(
                                domain: "StreamMerger", code: -9,
                                userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]
                            ))
                        default:
                            finish(completion, NSError(
                                domain: "StreamMerger", code: -10,
                                userInfo: [NSLocalizedDescriptionKey: "Unknown export status: \(exportSession.status.rawValue)"]
                            ))
                        }
                    }
                } catch {
                    finish(completion, error)
                }
            }
        }
    }

    private static func makeAsset(url: URL, mimeType: String) -> AVURLAsset {
        var options: [String: Any] = [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ]

        if #available(iOS 17.0, *) {
            options[AVURLAssetOverrideMIMETypeKey] = mimeType
        }

        return AVURLAsset(url: url, options: options)
    }

    private static func validate(asset: AVAsset, keys: [String]) -> Error? {
        for key in keys {
            var error: NSError?
            let status = asset.statusOfValue(forKey: key, error: &error)
            if status != .loaded {
                return NSError(
                    domain: "StreamMerger", code: -100,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Failed to load asset key '\(key)': \(error?.localizedDescription ?? "unknown error")"
                    ]
                )
            }
        }
        return nil
    }

    private static func finish(_ completion: @escaping (Error?) -> Void, _ error: Error?) {
        DispatchQueue.main.async {
            completion(error)
        }
    }
}
