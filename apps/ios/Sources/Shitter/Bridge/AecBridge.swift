import Foundation

final class AecBridge: @unchecked Sendable {
    private let handle: UnsafeMutableRawPointer
    private let processorLock = NSLock()
    private var renderTail: [Float] = []
    private var captureTail: [Float] = []
    private var hasRenderReference = false

    let frameSize: Int

    init?(sampleRate: UInt32) {
        guard let handle = aec_create(sampleRate) else {
            return nil
        }

        let frameSize = aec_get_frame_size(handle)
        guard frameSize > 0 else {
            aec_destroy(handle)
            return nil
        }

        self.handle = handle
        self.frameSize = frameSize
    }

    deinit {
        aec_destroy(handle)
    }

    func analyzeRender(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        processorLock.lock()
        defer { processorLock.unlock() }

        var pending = renderTail
        pending.append(contentsOf: samples)

        let processCount = pending.count / frameSize * frameSize
        if processCount > 0 {
            pending.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                let result = aec_analyze_render(handle, baseAddress, processCount)
                if result < 0 {
                    NSLog("[aec] analyze_render failed: %d", result)
                } else {
                    hasRenderReference = true
                }
            }
        }

        renderTail = processCount == pending.count ? [] : Array(pending[processCount...])
    }

    func processCapture(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }

        processorLock.lock()
        defer { processorLock.unlock() }

        var pending = captureTail
        pending.append(contentsOf: samples)

        let processCount = pending.count / frameSize * frameSize
        captureTail = processCount == pending.count ? [] : Array(pending[processCount...])

        guard processCount > 0 else {
            return []
        }

        var processBuffer = Array(pending[..<processCount])
        guard hasRenderReference else {
            return processBuffer
        }

        processBuffer.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            let result = aec_process_capture(handle, baseAddress, processCount)
            if result < 0 {
                NSLog("[aec] process_capture failed: %d", result)
            }
        }

        return processBuffer
    }
}
