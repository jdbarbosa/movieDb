import UIKit

/// Shown instead of the app when no TMDB key is configured, so a clean checkout still runs.
final class MissingAPIKeyViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let label = UILabel()
    label.numberOfLines = 0
    label.textAlignment = .center
    label.font = .preferredFont(forTextStyle: .body)
    label.textColor = .secondaryLabel
    label.text = """
    Missing TMDB API key.

    Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig, \
    add your key, and run `xcodegen generate`.
    """
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
    ])
  }
}
