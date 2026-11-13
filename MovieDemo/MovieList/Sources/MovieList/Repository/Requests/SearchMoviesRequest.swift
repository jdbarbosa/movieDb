import Foundation
import APIClient
import Models

struct SearchMoviesRequest: APIRequest {
  typealias Response = MovieListResponse

  let page: Int
  let query: String

  var path: String { "/search/movie" }
  var queryItems: [URLQueryItem]? {
    [
      URLQueryItem(name: "query", value: query),
      URLQueryItem(name: "page", value: "\(page)")
    ]
  }
}
