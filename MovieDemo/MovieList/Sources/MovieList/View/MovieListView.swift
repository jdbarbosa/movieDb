import SwiftUI
import Models
import MovieUI

struct MovieListView: View {

  let viewModel: MovieListViewModel

  var body: some View {
    Group {
      if let message = viewModel.errorMessage, viewModel.movies.isEmpty {
        errorState(message)
      } else if viewModel.movies.isEmpty, !viewModel.isLoadingFirstPage, case .search = viewModel.mode {
        ContentUnavailableView.search
      } else {
        list
      }
    }
    .overlay {
      if viewModel.isLoadingFirstPage {
        ProgressView()
      }
    }
  }

  private var list: some View {
    List {
      ForEach(viewModel.movies) { movie in
        Button {
          viewModel.movieWasTapped(movie)
        } label: {
          MovieCell(movie: movie)
        }
        .buttonStyle(.plain)
        .onAppear { viewModel.loadNextPageIfNeeded(currentItem: movie) }
      }
      footer
    }
    .listStyle(.plain)
  }

  @ViewBuilder
  private var footer: some View {
    if viewModel.isLoadingNextPage {
      HStack {
        Spacer()
        ProgressView()
        Spacer()
      }
      .listRowSeparator(.hidden)
    } else if let message = viewModel.errorMessage, !viewModel.movies.isEmpty {
      VStack(spacing: 8) {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Button("Retry") { viewModel.retry() }
          .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .listRowSeparator(.hidden)
    }
  }

  private func errorState(_ message: String) -> some View {
    ContentUnavailableView {
      Label("Something went wrong", systemImage: "exclamationmark.triangle")
    } description: {
      Text(message)
    } actions: {
      Button("Retry") { viewModel.retry() }
        .buttonStyle(.borderedProminent)
    }
  }
}
