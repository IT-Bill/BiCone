package cn.itbill.bicone

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.nio.ByteBuffer

/**
 * Merges separate video and audio files into a single MP4 using Android's native MediaMuxer.
 */
object MediaMuxerHelper {

    fun mergeStreams(videoPath: String, audioPath: String, outputPath: String) {
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()

        try {
            videoExtractor.setDataSource(videoPath)
            audioExtractor.setDataSource(audioPath)

            // Find and add video track
            val videoTrackIndex = selectTrack(videoExtractor, "video/")
            if (videoTrackIndex < 0) {
                throw IllegalArgumentException("No video track found in $videoPath")
            }
            videoExtractor.selectTrack(videoTrackIndex)
            val videoFormat = videoExtractor.getTrackFormat(videoTrackIndex)
            val muxerVideoTrack = muxer.addTrack(videoFormat)

            // Find and add audio track
            val audioTrackIndex = selectTrack(audioExtractor, "audio/")
            if (audioTrackIndex < 0) {
                throw IllegalArgumentException("No audio track found in $audioPath")
            }
            audioExtractor.selectTrack(audioTrackIndex)
            val audioFormat = audioExtractor.getTrackFormat(audioTrackIndex)
            val muxerAudioTrack = muxer.addTrack(audioFormat)

            muxer.start()

            // Write video samples
            writeSamples(videoExtractor, muxer, muxerVideoTrack)

            // Write audio samples
            writeSamples(audioExtractor, muxer, muxerAudioTrack)

            muxer.stop()
        } finally {
            videoExtractor.release()
            audioExtractor.release()
            muxer.release()
        }
    }

    private fun selectTrack(extractor: MediaExtractor, mimePrefix: String): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(mimePrefix)) {
                return i
            }
        }
        return -1
    }

    private fun writeSamples(extractor: MediaExtractor, muxer: MediaMuxer, trackIndex: Int) {
        val bufferSize = 1024 * 1024 // 1MB buffer
        val buffer = ByteBuffer.allocate(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break

            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = extractor.sampleTime
            bufferInfo.flags = extractor.sampleFlags

            muxer.writeSampleData(trackIndex, buffer, bufferInfo)
            extractor.advance()
        }
    }
}
