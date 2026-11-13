import SwiftUI
import MovieUI

struct MovieCollectionView: View {

  let viewModel: MovieCollectionViewModel

  var body: some View {
    Group {
      if let message = viewModel.errorMessage, viewModel.movies.isEmpty {
        VStack(spacing: 12) {
          Text(message)
            .foregroundStyle(.secondary)
          Button("Retry") { viewModel.reload() }
            .buttonStyle(.bordered)
        }
      } else if viewModel.movies.isEmpty, !viewModel.isLoading {
        ContentUnavailableView(viewModel.emptyMessage, systemImage: viewModel.collection.systemImage)
      } else {
        list
      }
    }
    .overlay {
      if viewModel.isLoading, viewModel.movies.isEmpty {
        ProgressView()
      }
    }
  }

  private var list: some View {
    VStack(spacing: 0) {
      if let message = viewModel.errorMessage {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .padding(.vertical, 8)
      }
      rows
    }
  }

  private var rows: some View {
    List(viewModel.movies) { stored in
      Button {
        viewModel.movieWasTapped(stored.movie)
      } label: {
        MovieCell(movie: stored.movie)
      }
      .buttonStyle(.plain)
      .swipeActions {
        Button("Remove", role: .destructive) {
          viewModel.remove(stored.movie)
        }
      }
    }
    .listStyle(.plain)
  }
}
