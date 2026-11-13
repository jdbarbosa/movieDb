import Foundation
import APIClient
import Models

struct PopularMoviesRequest: APIRequest {
  typealias Response = MovieListResponse

  let page: Int

  var path: String { "/movie/popular" }
  var queryItems: [URLQueryItem]? {
    [URLQueryItem(name: "page", value: "\(page)")]
  }
}
