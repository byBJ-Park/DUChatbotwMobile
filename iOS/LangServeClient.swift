import Foundation
import SwiftUI

@available(macOS 10.15, iOS 15.0, tvOS 13.0, watchOS 6.0, *)
public class LangServeClient {
    private let https: Bool
    private let hostname: String
    private let path: String
    private let baseUrl: String
    
    public init(
        https: Bool = false,
        hostname: String = "localhost",
        path: String = "llama"
    ) {
        self.https = https
        self.hostname = hostname
        self.path = path
        self.baseUrl = "\(https ? "https" : "http")://\(hostname)/\(path)"
    }
    
    // MARK: - SSE(Streaming) 관련 메서드
    public func stream(message: String) -> AsyncStream<String> {
        return stream(messages: [Message(speaker: MessageSpeaker.human, content: message)])
    }
    
    public func stream(messages: [Message]) -> AsyncStream<String> {
        return stream(messages: StreamRequest(input: messages))
    }
    
    public func stream(messages: StreamRequest) -> AsyncStream<String> {
        AsyncStream { continuation in
            let body = try? JSONEncoder().encode(messages)
            
            var request = URLRequest(url: .init(string: "\(baseUrl)")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    dump(error)
                    continuation.finish()
                    return
                }
                
                if let messageString = String(data: data, encoding: .utf8) {
                    messageString.enumerateLines { line, _ in
                        if line.starts(with: "data: ") {
                            let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                            
                            if let data = jsonString.data(using: .utf8),
                               let response = try? JSONDecoder().decode(StreamResponse.self, from: data) {
                                continuation.yield(response.content)
                            }
                        }
                    }
                }
                
                continuation.finish()
            }
            
            task.resume()
        }
    }
    
    // MARK: - 단일 요청-응답용 메서드 추가

    public func queryOnce(question: String) async throws -> RAGResponse {
        struct QueryRequest: Encodable {
            let question: String
        }
        
        let requestBody = QueryRequest(question: question)
        let bodyData = try JSONEncoder().encode(requestBody)
        
        guard let url = URL(string: baseUrl) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Decoding to JSON
        let ragResponse = try JSONDecoder().decode(RAGResponse.self, from: data)
        return ragResponse
    }
}

// MARK: - 응답 디코딩용 구조체
public struct RAGResponse: Decodable {
    public let question: String
    public let context: String
    public let answer: String
}

// (기존 Message, StreamRequest, StreamResponse 구조체 등도 필요하다면 동일 파일 or 다른 파일에 선언)
