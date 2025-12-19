import Foundation

// MARK: - BYO Provider Configuration

enum BYOProviderType: String, Codable, CaseIterable {
    case openAI
    case anthropic
    case custom
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .custom: return "Custom"
        }
    }
}

struct BYOProviderConfig: Codable {
    var providerType: BYOProviderType
    var apiKey: String
    var apiEndpoint: String?
    var modelName: String?
    
    static let `default` = BYOProviderConfig(
        providerType: .openAI,
        apiKey: "",
        apiEndpoint: nil,
        modelName: nil
    )
}

// MARK: - BYO Provider

class BYOProvider: AIProvider {
    let name = "BYO"
    
    let capabilities = AICapabilities(
        offline: false,
        supportsTools: true,
        supportsSchema: true,
        maxContextTokens: 128000,
        supportedTaskKinds: Set(AITaskKind.allCases)
    )
    
    private var config: BYOProviderConfig
    
    init(config: BYOProviderConfig) {
        self.config = config
    }
    
    func generate(prompt: String, taskKind: AITaskKind, options: AIGenerateOptions) async throws -> AIResult {
        let startTime = Date()
        
        guard !config.apiKey.isEmpty else {
            throw AIError.providerUnavailable("API key not configured")
        }
        
        let content = try await callExternalAPI(prompt: prompt, taskKind: taskKind, options: options)
        
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        return AIResult(
            content: content,
            metadata: AIResultMetadata(
                provider: name,
                latencyMs: latencyMs,
                tokenCount: nil,
                model: config.modelName,
                timestamp: Date()
            )
        )
    }
    
    private func callExternalAPI(prompt: String, taskKind: AITaskKind, options: AIGenerateOptions) async throws -> String {
        switch config.providerType {
        case .openAI:
            return try await callOpenAI(prompt: prompt, options: options)
        case .anthropic:
            return try await callAnthropic(prompt: prompt, options: options)
        case .custom:
            return try await callCustomEndpoint(prompt: prompt, options: options)
        }
    }
    
    private func callOpenAI(prompt: String, options: AIGenerateOptions) async throws -> String {
        let endpoint = config.apiEndpoint ?? "https://api.openai.com/v1/chat/completions"
        let model = config.modelName ?? "gpt-4"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages: [[String: String]] = [
            options.systemPrompt.map { ["role": "system", "content": $0] },
            ["role": "user", "content": prompt]
        ].compactMap { $0 }
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": options.temperature ?? 0.7,
            "max_tokens": options.maxTokens ?? 2000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIError.generationFailed("API request failed")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content
    }
    
    private func callAnthropic(prompt: String, options: AIGenerateOptions) async throws -> String {
        let endpoint = config.apiEndpoint ?? "https://api.anthropic.com/v1/messages"
        let model = config.modelName ?? "claude-3-5-sonnet-20241022"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let messages: [[String: String]] = [
            ["role": "user", "content": prompt]
        ]
        
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": options.maxTokens ?? 2000
        ]
        
        if let systemPrompt = options.systemPrompt {
            body["system"] = systemPrompt
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIError.generationFailed("API request failed")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.invalidResponse
        }
        
        return text
    }
    
    private func callCustomEndpoint(prompt: String, options: AIGenerateOptions) async throws -> String {
        guard let endpoint = config.apiEndpoint else {
            throw AIError.providerUnavailable("Custom endpoint not configured")
        }
        
        // Basic custom endpoint implementation
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "prompt": prompt,
            "temperature": options.temperature ?? 0.7,
            "max_tokens": options.maxTokens ?? 2000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIError.generationFailed("API request failed")
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw AIError.invalidResponse
        }
        
        return content
    }
    
    // MARK: - Configuration
    
    func updateConfig(_ newConfig: BYOProviderConfig) {
        self.config = newConfig
    }
}
