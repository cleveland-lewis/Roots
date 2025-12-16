import Foundation
@testable import Roots

/// Fake LLM client for testing with scriptable outputs and failure injection
class FakeLLMClient: LLMBackend {
    var config: LLMBackendConfig
    var isAvailable: Bool = true
    
    // Scriptable responses
    private var responseQueue: [Result<String, Error>] = []
    private var currentIndex = 0
    
    // Statistics
    var callCount = 0
    var lastPrompt: String?
    var allPrompts: [String] = []
    
    // Behavior configuration
    var alwaysFail = false
    var failureRate: Double = 0.0 // 0.0 = never fail, 1.0 = always fail
    var delaySeconds: TimeInterval = 0.0
    
    init(config: LLMBackendConfig = .mockConfig) {
        self.config = config
    }
    
    // MARK: - Response Scripting
    
    /// Queue a successful response
    func queueSuccess(_ jsonResponse: String) {
        responseQueue.append(.success(jsonResponse))
    }
    
    /// Queue a failure
    func queueFailure(_ error: Error = LLMBackendError.invalidResponse("Scripted failure")) {
        responseQueue.append(.failure(error))
    }
    
    /// Queue multiple successful responses
    func queueSuccesses(_ responses: [String]) {
        responses.forEach { queueSuccess($0) }
    }
    
    /// Queue a pattern: e.g., [fail, fail, success]
    func queuePattern(failures: Int, thenSuccess response: String) {
        for _ in 0..<failures {
            queueFailure()
        }
        queueSuccess(response)
    }
    
    /// Clear all queued responses
    func reset() {
        responseQueue.removeAll()
        currentIndex = 0
        callCount = 0
        lastPrompt = nil
        allPrompts.removeAll()
        alwaysFail = false
        failureRate = 0.0
    }
    
    // MARK: - LLMBackend Implementation
    
    func generate(prompt: String) async throws -> LLMResponse {
        callCount += 1
        lastPrompt = prompt
        allPrompts.append(prompt)
        
        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }
        
        // Check if we should inject a failure
        if alwaysFail {
            throw LLMBackendError.invalidResponse("Always fail mode enabled")
        }
        
        if failureRate > 0 && Double.random(in: 0...1) < failureRate {
            throw LLMBackendError.invalidResponse("Random failure injected")
        }
        
        // Get next scripted response
        guard currentIndex < responseQueue.count else {
            throw LLMBackendError.invalidResponse("No more scripted responses")
        }
        
        let result = responseQueue[currentIndex]
        currentIndex += 1
        
        switch result {
        case .success(let text):
            return LLMResponse(
                text: text,
                tokensUsed: text.count / 4, // Rough estimate
                finishReason: "stop",
                model: config.modelName,
                latencyMs: delaySeconds * 1000
            )
        case .failure(let error):
            throw error
        }
    }
    
    func generateJSON(prompt: String, schema: String?) async throws -> String {
        let response = try await generate(prompt: prompt)
        return response.text
    }
}

// MARK: - Convenience Builders

extension FakeLLMClient {
    /// Create a client that always returns valid questions
    static func alwaysValid() -> FakeLLMClient {
        let client = FakeLLMClient()
        // Will be populated per test
        return client
    }
    
    /// Create a client that always fails
    static func alwaysFails() -> FakeLLMClient {
        let client = FakeLLMClient()
        client.alwaysFail = true
        return client
    }
    
    /// Create a client with specific failure rate
    static func withFailureRate(_ rate: Double) -> FakeLLMClient {
        let client = FakeLLMClient()
        client.failureRate = rate
        return client
    }
}
