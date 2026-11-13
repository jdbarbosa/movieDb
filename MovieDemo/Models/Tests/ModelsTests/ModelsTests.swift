import Foundation
import Testing
@testable import Models

@Suite("Models")
struct ModelsTests {

  private let decoder = JSONDecoder()

  @Test func decodesPopularPage() throws {
    let json = """
    {"page":1,"total_pages":3,"total_results":60,
     "results":[{"id":1,"title":"A","poster_path":"/a.jpg","vote_average":7.5,"release_date":"2024-05-01","overview":"x"}]}
    """
    let page = try decoder.decode(MovieListResponse.self, from: Data(json.utf8))
    #expect(page.page == 1)
    #expect(page.totalPages == 3)
    #expect(page.totalResults == 60)
    let movie = try #require(page.results.first)
    #expect(movie.id == 1)
    #expect(movie.title == "A")
    #expect(movie.posterPath == "/a.jpg")
    #expect(movie.voteAverage == 7.5)
    #expect(movie.overview == "x")
    #expect(movie.releaseYear == "2024")
    #expect(movie.runtime == nil)
  }

  @Test func decodesDetailPayload() throws {
    let json = """
    {"id":7,"title":"D","runtime":120,"tagline":"T","genres":[{"id":28,"name":"Action"}],"vote_count":10,"backdrop_path":"/b.jpg"}
    """
    let movie = try decoder.decode(Movie.self, from: Data(json.utf8))
    #expect(movie.runtime == 120)
    #expect(movie.tagline == "T")
    #expect(movie.genres == [Genre(id: 28, name: "Action")])
    #expect(movie.voteCount == 10)
    #expect(movie.backdropPath == "/b.jpg")
  }

  @Test func decodesEmptyReleaseDate() throws {
    let json = #"{"id":1,"title":"A","release_date":""}"#
    let movie = try decoder.decode(Movie.self, from: Data(json.utf8))
    #expect(movie.releaseYear == nil)
  }

  @Test func imageURLBuildsForPath() {
    #expect(TMDBImage.url(path: "/a.jpg", size: .w185)?.absoluteString == "https://image.tmdb.org/t/p/w185/a.jpg")
  }

  @Test func imageURLIsNilWithoutPath() {
    #expect(TMDBImage.url(path: nil, size: .w500) == nil)
  }
}
