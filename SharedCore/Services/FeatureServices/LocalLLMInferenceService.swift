import Foundation
import CoreML

/// Configuration for text generation
public struct GenerationConfig: Sendable {
    public var temperature: Double
    public var topP: Double
    public var maxTokens: Int
    public var stopSequences: [String]
    
    public init(
        temperature: Double = 0.7,
        topP: Double = 0.9,
        maxTokens: Int = 512,
        stopSequences: [String] = []
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
    }
    
    public static let `default` = GenerationConfig()
    
    public static let practiceTestJSON = GenerationConfig(
        temperature: 0.3, // Lower temperature for more deterministic output
        topP: 0.95,
        maxTokens: 2048,
        stopSequences: ["}"]
    )
}

/// Core ML-based local LLM inference service
public actor LocalLLMInferenceService {
    
    // MARK: - State
    
    private var loadedModel: MLModel?
    private var currentModelEntry: LocalModelEntry?
    private var isWarmedUp = false
    
    // MARK: - Model Loading
    
    /// Load a Core ML model from disk
    public func loadModel(_ entry: LocalModelEntry) async throws {
        guard LocalModelCatalog.isModelInstalled(entry) else {
            throw LLMInferenceError.modelNotInstalled(entry.id)
        }
        
        let modelPath = LocalModelCatalog.modelPath(entry: entry)
        
        // Configure model for best performance on Apple Silicon
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        configuration.allowLowPrecisionAccumulationOnGPU = true
        
        // Load model
        let compiledModelURL = try MLModel.compileModel(at: modelPath)
        let model = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        
        loadedModel = model
        currentModelEntry = entry
        isWarmedUp = false
        
        print("[LocalLLMInferenceService] Loaded model: \(entry.id) v\(entry.version)")
    }
    
    /// Warm up model with a simple prompt to avoid first-token stall
    public func warmUp() async throws {
        guard !isWarmedUp, let model = loadedModel else {
            return
        }
        
        print("[LocalLLMInferenceService] Warming up model...")
        
        // Generate a short test sequence
        _ = try await generateSimple(prompt: "Hello", maxTokens: 5)
        
        isWarmedUp = true
        print("[LocalLLMInferenceService] Warm-up complete")
    }
    
    // MARK: - Generation (Streaming)
    
    /// Generate text with streaming tokens
    public func generate(prompt: String, config: GenerationConfig = .default) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    guard let model = loadedModel else {
                        continuation.finish()
                        return
                    }
                    
                    // Warm up if needed
                    if !isWarmedUp {
                        try await warmUp()
                    }
                    
                    // Generate tokens
                    let tokens = try await generateTokens(
                        model: model,
                        prompt: prompt,
                        config: config
                    )
                    
                    // Stream tokens
                    for token in tokens {
                        continuation.yield(token)
                        
                        // Check for stop sequences
                        if config.stopSequences.contains(where: { token.contains($0) }) {
                            break
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    print("[LocalLLMInferenceService] Generation error: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Generate practice test JSON with streaming
    public func generatePracticeTestJSON(spec: PracticeTestSpec) -> AsyncStream<String> {
        let prompt = buildPracticeTestPrompt(spec: spec)
        return generate(prompt: prompt, config: .practiceTestJSON)
    }
    
    // MARK: - Private Helpers
    
    /// Generate tokens using Core ML model
    private func generateTokens(
        model: MLModel,
        prompt: String,
        config: GenerationConfig
    ) async throws -> [String] {
        // Note: This is a simplified implementation
        // Real Core ML LLM models have specific input/output schemas
        // You'll need to adapt this to your actual model's interface
        
        var tokens: [String] = []
        var currentPrompt = prompt
        
        for _ in 0..<config.maxTokens {
            // Prepare input
            guard let input = try? prepareInput(prompt: currentPrompt, model: model) else {
                break
            }
            
            // Run prediction
            guard let output = try? model.prediction(from: input) else {
                break
            }
            
            // Extract next token
            guard let nextToken = extractToken(from: output) else {
                break
            }
            
            tokens.append(nextToken)
            currentPrompt += nextToken
            
            // Check for stop
            if config.stopSequences.contains(where: { nextToken.contains($0) }) {
                break
            }
        }
        
        return tokens
    }
    
    /// Simple non-streaming generation for warm-up
    private func generateSimple(prompt: String, maxTokens: Int) async throws -> String {
        guard let model = loadedModel else {
            throw LLMInferenceError.modelNotLoaded
        }
        
        let tokens = try await generateTokens(
            model: model,
            prompt: prompt,
            config: GenerationConfig(maxTokens: maxTokens)
        )
        
        return tokens.joined()
    }
    
    /// Prepare model input (adapt to your model's schema)
    private func prepareInput(prompt: String, model: MLModel) throws -> MLFeatureProvider {
        // This is a placeholder - adapt to your actual Core ML model's input schema
        // Common patterns:
        // 1. Text input: MLDictionaryFeatureProvider with "input_text" key
        // 2. Token IDs: MLMultiArray with tokenized input
        
        let inputDict: [String: Any] = [
            "input_text": prompt
        ]
        
        return try MLDictionaryFeatureProvider(dictionary: inputDict)
    }
    
    /// Extract token from model output (adapt to your model's schema)
    private func extractToken(from output: MLFeatureProvider) -> String? {
        // This is a placeholder - adapt to your actual Core ML model's output schema
        // Common patterns:
        // 1. Text output: featureValue(for: "output_text")?.stringValue
        // 2. Token IDs: featureValue(for: "token_ids")?.multiArrayValue
        
        return output.featureValue(for: "output_text")?.stringValue
    }
    
    /// Build prompt for practice test generation
    private func buildPracticeTestPrompt(spec: PracticeTestSpec) -> String {
        """
        Generate a practice test in JSON format with the following specifications:
        
        Subject: \(spec.subject)
        Unit: \(spec.unitName)
        Difficulty: \(spec.difficulty)/5
        Number of Questions: \(spec.numQuestions)
        Question Types: \(spec.questionTypes.map(\.rawValue).joined(separator: ", "))
        
        Return ONLY valid JSON in this exact format:
        {
          "questions": [
            {
              "id": "q1",
              "type": "MCQ",
              "stem": "Question text here",
              "correctAnswer": "The correct answer",
              "distractors": ["Wrong answer 1", "Wrong answer 2", "Wrong answer 3"],
              "rationale": "Explanation of why the correct answer is correct"
            }
          ]
        }
        
        Requirements:
        - Each MCQ must have exactly 1 correct answer and 3 distinct distractors
        - Question stems must be unambiguous
        - Rationales must explain the correct answer
        - All distractors must be plausible but definitively incorrect
        
        JSON:
        """
    }
    
    // MARK: - Cleanup
    
    public func unloadModel() {
        loadedModel = nil
        currentModelEntry = nil
        isWarmedUp = false
        print("[LocalLLMInferenceService] Model unloaded")
    }
}

// MARK: - Errors

public enum LLMInferenceError: Error, LocalizedError {
    case modelNotLoaded
    case modelNotInstalled(String)
    case generationFailed(String)
    case invalidOutput
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is currently loaded"
        case .modelNotInstalled(let id):
            return "Model \(id) is not installed"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .invalidOutput:
            return "Model produced invalid output"
        }
    }
}

// MARK: - Practice Test Spec

public struct PracticeTestSpec: Codable, Sendable {
    public var subject: String
    public var unitName: String
    public var difficulty: Int // 1-5
    public var numQuestions: Int
    public var questionTypes: [QuestionType]
    public var timeLimit: Int? // seconds, optional
    
    public init(
        subject: String,
        unitName: String,
        difficulty: Int,
        numQuestions: Int,
        questionTypes: [QuestionType],
        timeLimit: Int? = nil
    ) {
        self.subject = subject
        self.unitName = unitName
        self.difficulty = difficulty
        self.numQuestions = numQuestions
        self.questionTypes = questionTypes
        self.timeLimit = timeLimit
    }
    
    public enum QuestionType: String, Codable, CaseIterable, Sendable {
        case mcq = "MCQ"
        case shortAnswer = "SA"
    }
}
