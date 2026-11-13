import SwiftUI
import Models

struct MovieDetailView: View {

  let viewModel: MovieDetailViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        poster
        VStack(alignment: .leading, spacing: 12) {
          Text(viewModel.movie.title)
            .font(.title)
            .bold()
          if let tagline = viewModel.movie.tagline, !tagline.isEmpty {
            Text(tagline)
              .font(.subheadline)
              .italic()
              .foregroundStyle(.secondary)
          }
          metadata
          genres
          if let overview = viewModel.movie.overview, !overview.isEmpty {
            Text("Overview")
              .font(.headline)
              .padding(.top, 8)
            Text(overview)
              .font(.body)
          }
          errorBanner
        }
        .padding(.horizontal)
      }
      .padding(.bottom, 24)
    }
    .ignoresSafeArea(edges: .top)
    .overlay {
      if viewModel.state == .loading {
        ProgressView()
          .padding(12)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private var poster: some View {
    AsyncImage(url: TMDBImage.url(path: viewModel.movie.posterPath, size: .w500)) { phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFill()
      case .failure:
        Image(systemName: "photo")
          .resizable()
          .scaledToFit()
          .padding(60)
          .foregroundStyle(.secondary)
      default:
        Color.secondary.opacity(0.2)
      }
    }
    .frame(height: 420)
    .frame(maxWidth: .infinity)
    .clipped()
  }

  @ViewBuilder
  private var metadata: some View {
    HStack(spacing: 12) {
      if let year = viewModel.movie.releaseYear {
        Text(year)
      }
      if let runtime = viewModel.movie.runtime, runtime > 0 {
        Text("\(runtime) min")
      }
      if let rating = viewModel.movie.voteAverage {
        Label(String(format: "%.1f", rating), systemImage: "star.fill")
          .foregroundStyle(.yellow)
      }
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var genres: some View {
    if let genres = viewModel.movie.genres, !genres.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(genres) { genre in
            Text(genre.name)
              .font(.caption)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color.accentColor.opacity(0.15), in: Capsule())
          }
        }
      }
    }
  }

  @ViewBuilder
  private var errorBanner: some View {
    if case .failed(let message) = viewModel.state {
      VStack(alignment: .leading, spacing: 8) {
        Label(message, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
        Button("Retry") { viewModel.retry() }
          .buttonStyle(.bordered)
      }
      .padding(.top, 8)
    }
  }
}
