import UIKit

/// Gate Menu - 테스트 선택 화면
final class GateMenuViewController: UIViewController {

    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "PickPhoto Gate Tests"
        view.backgroundColor = .systemBackground

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])

        // Gate 1 (Spike 1) - 더미 데이터
        let gate1Button = createButton(
            title: "Gate 1: Data Source",
            subtitle: "performBatchUpdates (Spike 1 완료)",
            color: .systemGreen,
            action: #selector(openGate1)
        )
        stackView.addArrangedSubview(gate1Button)

        // Separator
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)

        // Gate 2 Header
        let gate2Label = UILabel()
        gate2Label.text = "Gate 2: Image Loading"
        gate2Label.font = .preferredFont(forTextStyle: .headline)
        gate2Label.textAlignment = .center
        stackView.addArrangedSubview(gate2Label)

        // Gate 2 - Mock (현재 가능)
        let gate2MockButton = createButton(
            title: "Mock Provider",
            subtitle: "랜덤 색상 이미지 + 2ms 지연",
            color: .systemBlue,
            action: #selector(openGate2Mock)
        )
        stackView.addArrangedSubview(gate2MockButton)

        // Gate 2 - PhotoKit (실사진 필요)
        let gate2PhotoKitButton = createButton(
            title: "PhotoKit Provider",
            subtitle: "실제 사진 라이브러리 (실기기 필요)",
            color: .systemOrange,
            action: #selector(openGate2PhotoKit)
        )
        stackView.addArrangedSubview(gate2PhotoKitButton)

        // Separator 2
        let separator2 = UIView()
        separator2.backgroundColor = .separator
        separator2.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator2)

        // Gate 3
        let gate3Button = createButton(
            title: "Gate 3: Pinch Zoom",
            subtitle: "1/3/5열 전환 + 앵커 유지 테스트",
            color: .systemPurple,
            action: #selector(openGate3)
        )
        stackView.addArrangedSubview(gate3Button)

        // Gate 4
        let gate4Button = createButton(
            title: "Gate 4: 120Hz Tuning",
            subtitle: "ProMotion ON/OFF 비교 테스트",
            color: .systemRed,
            action: #selector(openGate4)
        )
        stackView.addArrangedSubview(gate4Button)

        // Info label
        let infoLabel = UILabel()
        infoLabel.text = "측정 인프라: HitchMonitor + BenchmarkMetrics\nApple 기준: < 5 ms/s = Good"
        infoLabel.font = .preferredFont(forTextStyle: .footnote)
        infoLabel.textColor = .secondaryLabel
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        stackView.addArrangedSubview(infoLabel)
    }

    private func createButton(title: String, subtitle: String, color: UIColor, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.subtitle = subtitle
        config.baseBackgroundColor = color
        config.cornerStyle = .large
        config.buttonSize = .large

        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func openGate1() {
        let vc = Spike1ViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate2Mock() {
        let provider = MockImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "Mock")
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate2PhotoKit() {
        let provider = PhotoKitImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "PhotoKit")
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate3() {
        let vc = Gate3ViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate4() {
        let vc = Gate4ViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}
