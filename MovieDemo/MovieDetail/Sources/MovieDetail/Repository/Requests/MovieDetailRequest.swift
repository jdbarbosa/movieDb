import Foundation
import APIClient
import Models

struct MovieDetailRequest: APIRequest {
  typealias Response = Movie

  let id: Int

  var path: String { "/movie/\(id)" }
  var queryItems: [URLQueryItem]? { nil }
}
