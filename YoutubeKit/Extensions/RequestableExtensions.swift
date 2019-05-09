//
//  RequestableExtensions.swift
//  YoutubeKit
//
//  Created by Ryo Ishikawa on 12/30/2017
//

public extension Requestable {
    
    var baseURL: URL {
        return URL(string: "https://www.googleapis.com/youtube/\(YoutubeKit.youtubeDataAPIVersion)/")!
    }
    
    var queryParameters: [String: Any] {
        return [:]
    }
    
    var headerField: [String: String] {
        var header: [String: String] = [:]
        if isAuthorizedRequest {
            header["Authorization"] = "Bearer \(YoutubeKit.shared.accessToken)"
        }
        return header
    }
    
    var isAuthorizedRequest: Bool {
        return false
    }
    
    var httpBody: Data? {
        return nil
    }

    func makeURLRequest() -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        var header: [String: String] = headerField
        
        urlRequest.httpMethod = httpMethod.rawValue
        
        if isAuthorizedRequest && !header.contains(where: { $0.key == "Authorization" }) {
            header["Authorization"] = "Bearer \(YoutubeKit.shared.accessToken)"
        }
        
        header.forEach { key, value in
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        
        if let body = httpBody {
            urlRequest.httpBody = body
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return urlRequest
        }

        var keyParams: [String: Any] = queryParameters
        
        if !isAuthorizedRequest {
            keyParams["key"] = YoutubeKit.shared.apiKey
        }
        
        urlComponents.query = keyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        urlRequest.url = urlComponents.url
        
        return urlRequest
    }
}
