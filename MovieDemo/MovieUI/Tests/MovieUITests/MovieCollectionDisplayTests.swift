import Testing
import MovieStore
@testable import MovieUI

@Suite("MovieCollection display")
struct MovieCollectionDisplayTests {

  @Test func titlesSymbolsAndSelectedSymbols() {
    let all = MovieCollection.allCases
    #expect(all.map(\.title) == ["Watchlist", "Seen", "Favourites"])
    #expect(all.map(\.systemImage) == ["bookmark", "checkmark.circle", "heart"])
    #expect(all.map(\.selectedSystemImage) == ["bookmark.fill", "checkmark.circle.fill", "heart.fill"])
  }
}
