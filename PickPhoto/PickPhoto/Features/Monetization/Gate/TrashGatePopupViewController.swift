//
//  TrashGatePopupViewController.swift
//  PickPhoto
//
//  게이트 팝업 UI — 커스텀 중앙 팝업
//  반투명 배경 + 중앙 라운드 카드
//  modalPresentationStyle = .overFullScreen, crossDissolve
//
//  버튼 구성:
//  - 광고 버튼: "광고 N회 보고 X장 전체 삭제" (Ready/Loading/Failed 3상태)
//  - Plus 버튼: "Plus로 무제한"
//  - 닫기 버튼
//
//  오프라인 시: 광고/구독 비활성 + "인터넷 연결 필요" (FR-055)
//  리워드 소진 시: 골든 모먼트 (Plus 전환 유도, FR-014)
//

import UIKit
import AppCore
import OSLog

// MARK: - TrashGatePopupViewController

/// 게이트 커스텀 중앙 팝업
final class TrashGatePopupViewController: UIViewController {

    // MARK: - Callbacks

    /// 광고 시청 선택 시
    var onAdWatch: (() -> Void)?
    /// Plus 업그레이드 선택 시
    var onPlusUpgrade: (() -> Void)?
    /// 닫기 선택 시
    var onDismiss: (() -> Void)?

    // MARK: - Data

    /// 삭제 대상 수
    private let trashCount: Int
    /// 남은 기본 무료 삭제 수
    private let remainingFreeDeletes: Int
    /// 필요한 광고 수 (-1이면 광고로도 부족)
    private let adsNeeded: Int
    /// 남은 리워드 가능 횟수
    private let remainingRewards: Int

    // MARK: - UI Components

    /// 반투명 배경
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 중앙 카드 컨테이너
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 제목 라벨
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "삭제대기함을 비우려면"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 안내 라벨 (장수 · 한도 정보)
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 광고 버튼
    private let adButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }()

    /// Plus 버튼
    private let plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.setTitle("⭐ Plus로 무제한", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }()

    /// 닫기 버튼
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("닫기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 골든 모먼트 안내 라벨 (리워드 소진 시)
    private let goldenMomentLabel: UILabel = {
        let label = UILabel()
        label.text = "오늘 광고 횟수를 모두 사용했습니다"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 오프라인 안내 라벨
    private let offlineLabel: UILabel = {
        let label = UILabel()
        label.text = "인터넷 연결이 필요합니다"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    ///