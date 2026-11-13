import SwiftUI
import Models

/// One movie row: poster, title, year, rating. Shared by every list in the app.
public struct MovieCell: View {

  public let movie: Movie

  public init(movie: Movie) {
    self.movie = movie
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      AsyncImage(url: TMDBImage.url(path: movie.posterPath, size: .w185)) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFill()
        default:
          Color.secondary.opacity(0.2)
            .overlay(Image(systemName: "film").foregroundStyle(.secondary))
        }
      }
      .frame(width: 60, height: 90)
      .clipShape(RoundedRectangle(cornerRadius: 6))

      VStack(alignment: .leading, spacing: 6) {
        Text(movie.title)
          .font(.headline)
          .lineLimit(2)
        if let year = movie.releaseYear {
          Text(year)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        if let rating = movie.voteAverage {
          Label(String(format: "%.1f", rating), systemImage: "star.fill")
            .font(.subheadline)
            .foregroundStyle(.yellow)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
  }
}
