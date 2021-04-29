import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if swift(>=5.5)
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public struct AsyncAwaitFetcher {

    /// Fetches the contents of the given URL
    public static func fetch(url: String) async throws -> (response: HTTPURLResponse, data: Data) {
        // withUnsafeThrowingContinuation()
        // withCheckedThrowingContinuation()
        return try await withUnsafeThrowingContinuation { continuation in
            guard let url = URL(string: url) else { return }
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response as? HTTPURLResponse {
                    continuation.resume(returning: (response, data))
                }
            }
            task.resume()
        }

    }


    /// Fetch the data at the given URL and return it as an array of JSON Dictionaries
    public static func json(url: String) async throws -> [NSDictionary] {
        let response = try await fetch(url: url)
        let ob = try JSONSerialization.jsonObject(with: response.data, options: [])
        if let dict = ob as? NSDictionary {
            return [dict]
        } else if let dicts = ob as? [NSDictionary] {
            return dicts
        } else {
            return []
        }
    }
}

/// Errors from `AsyncAwaitFetcher.fetch`
public enum FetchError {
    case URLInvalid(String)
    case noResponseOrError
    case bothResponseAndError
    case nonHTTPResponse(URLResponse)
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
func downloadFlag(for language: String) async throws -> (info: NSDictionary, image: Data) {
    let results = try await AsyncAwaitFetcher.json(url: "https://restcountries.eu/rest/v2/lang/" + language)

    guard let infoDict = results.first else {
        throw WebServiceErrors.noValidResponse
    }

    guard let flagURL = infoDict["flag"] as? String else {
        throw WebServiceErrors.noFlag
    }

    let flagResponse = try await AsyncAwaitFetcher.fetch(url: flagURL)
    let flagData = flagResponse.data
    // let flagXML = try XMLDocument(data: flagData, options: [.nodeLoadExternalEntitiesNever])

    return (infoDict, flagData)

}

/// An error thrown from `downloadFlag`
enum WebServiceErrors : Error {
    case noValidResponse
    case noFlag
}
#endif
