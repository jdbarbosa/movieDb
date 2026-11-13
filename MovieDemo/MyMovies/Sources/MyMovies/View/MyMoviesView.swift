import SwiftUI
import MovieUI

struct MyMoviesView: View {

  let viewModel: MyMoviesViewModel

  var body: some View {
    VStack(spacing: 16) {
      ForEach(viewModel.sections, id: \.self) { collection in
        Button {
          viewModel.sectionTapped(collection)
        } label: {
          Label(collection.title, systemImage: collection.systemImage)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }
    }
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
  }
}
