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
        gate2Label.text = "Gate 2: Pipeline Test"
        gate2Label.font = .preferredFont(forTextStyle: .headline)
        gate2Label.textAlignment = .center
        stackView.addArrangedSubview(gate2Label)

        // Gate 2 - Baseline (Control)
        let baselineButton = createButton(
            title: "Baseline (Control)",
            subtitle: "현행: opportunistic + prepareForReuse",
            color: .systemGray,
            action: #selector(openGate2Baseline)
        )
        stackView.addArrangedSubview(baselineButton)

        // Gate 2 - Candidate A
        let candidateAButton = createButton(
            title: "후보 A",
            subtitle: "fastFormat + didEndDisplaying",
            color: .systemBlue,
            action: #selector(openGate2CandidateA)
        )
        stackView.addArrangedSubview(candidateAButton)

        // Gate 2 - Candidate D (추천)
        let candidateDButton = createButton(
            title: "후보 D ⭐",
            subtitle: "Adaptive 2-Stage (Photos 모방)",
            color: .systemGreen,
            action: #selector(openGate2CandidateD)
        )
        stackView.addArrangedSubview(candidateDButton)

        // Gate 2 - Candidate B (원인 분리)
        let candidateBButton = createButton(
            title: "후보 B1~B4",
            subtitle: "레버별 단계 테스트 (원인 분리)",
            color: .systemOrange,
            action: #selector(openGate2CandidateB)
        )
        stackView.addArrangedSubview(candidateBButton)

        // Gate 2 - Candidate C (최후)
        let candidateCButton = createButton(
            title: "후보 C",
            subtitle: "maxInFlight 8개 제한 (최후 안전장치)",
            color: .systemRed,
            action: #selector(openGate2CandidateC)
        )
        stackView.addArrangedSubview(candidateCButton)

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

    // MARK: - Gate 2 Pipeline Test Actions

    @objc private func openGate2Baseline() {
        let provider = PhotoKitImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "PhotoKit", pipeline: .baseline)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate2CandidateA() {
        let provider = PhotoKitImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "PhotoKit", pipeline: .candidateA)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate2CandidateD() {
        let provider = PhotoKitImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "PhotoKit", pipeline: .candidateD)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openGate2CandidateB() {
        // B1~B4 선택 Alert
        let alert = UIAlertController(title: "후보 B 선택", message: "레버별 단계 테스트", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "B1: preheat OFF", style: .default) { [weak self] _ in
            self?.openGate2Pipeline(.candidateB1)
        })
        alert.addAction(UIAlertAction(title: "B2: B1 + quality 30%", style: .default) { [weak self] _ in
            self?.openGate2Pipeline(.candidateB2)
        })
        alert.addAction(UIAlertAction(title: "B3: B2 + fastFormat", style: .default) { [weak self] _ in
            self?.openGate2Pipeline(.candidateB3)
        })
        alert.addAction(UIAlertAction(title: "B4: B3 + didEndDisplaying", style: .default) { [weak self] _ in
            self?.openGate2Pipeline(.candidateB4)
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(alert, animated: true)
    }

    @objc private func openGate2CandidateC() {
        let provider = PhotoKitImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "PhotoKit", pipeline: .candidateC)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openGate2Pipeline(_ pipeline: Gate2ViewController.PipelineCandidate) {
        let provider = PhotoKitImageProvider()
        let vc = Gate2ViewController(provider: provider, name: "PhotoKit", pipeline: pipeline)
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
