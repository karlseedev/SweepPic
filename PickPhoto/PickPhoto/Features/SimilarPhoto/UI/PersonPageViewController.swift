//
//  PersonPageViewController.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-19.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  단일 인물(personIndex)의 얼굴 그리드를 표시하는 페이지 뷰 컨트롤러입니다.
//  UIPageViewController의 자식으로 사용되며, 부모의 데이터를 참조합니다.
//
//  주요 기능:
//  - 2열 정사각형 그리드로 크롭된 얼굴 이미지 표시
//  - 셀 선택 시 부모에게 알림 (FaceComparisonDataSource 프로토콜)
//  - 셀 재사용 안전장치: completion 호출 전 assetID 확인
//

import UIKit
import AppCore
import Photos

// MARK: - FaceComparisonDataSource Protocol

/// 얼굴 비교 데이터 소스 프로토콜
///
/// PersonPageViewController가 부모(FaceComparisonViewController)의 데이터에 접근하기 위한
/// 행동 중심 API입니다. 저장 구조를 노출하지 않습니다.
protocol FaceComparisonDataSource: AnyObject {
    /// 특정 인물의 사진 목록 반환
    /// - Parameter personIndex: 인물 번호
    /// - Returns: assetID 배열
    func photosForPerson(_ personIndex: Int) -> [String]

    /// 선택 여부 확인
    /// - Parameter assetID: 사진 ID
    /// - Returns: 선택 여부
    func isSelected(_ assetID: String) -> Bool

    /// 선택 토글
    /// - Parameter assetID: 사진 ID
    func toggleSelection(for assetID: String)

    /// 얼굴 정보 가져오기
    /// - Parameters:
    ///   - assetID: 사진 ID
    ///   - personIndex: 인물 번호
    /// - Returns: CachedFace (없으면 nil)
    func face(for assetID: String, personIndex: Int) -> CachedFace?

    /// 크롭된 얼굴 이미지 로드
    /// - Parameters:
    ///   - assetID: 사진 ID
    ///   - personIndex: 인물 번호
    ///   - completion: 이미지 로드 완료 콜백 (메인 스레드)
    func loadFaceImage(
        assetID: String,
        personIndex: Int,
        completion: @escaping (UIImage?) -> Void
    )

    /// 유효 인물 인덱스 목록
    var validPersonIndices: [Int] { get }
}

// MARK: - PersonPageViewController

/// 단일 인물 페이지 뷰 컨트롤러
///
/// UIPageViewController의 자식으로 사용됩니다.
/// 해당 인물의 얼굴 이미지를 2열 그리드로 표시합니다.
final class PersonPageViewController: UIViewController {

    // MARK: - Constants

    /// 그리드 간격 (상하좌우)
    private static let gridSpacing: CGFloat = 2

    /// 최소 셀 크기 (화면이 너무 작을 때 보장)
    private static let minCellSize: CGFloat = 100

    // MARK: - Properties

    /// 표시할 인물 번호
    let personIndex: Int

    /// 데이터 소스 (부모 뷰 컨트롤러)
    weak var dataSource: FaceComparisonDataSource?

    // MARK: - UI Components

    /// 컬렉션 뷰 (2열 그리드)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Self.gridSpacing
        layout.minimumLineSpacing = Self.gridSpacing

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.register(FaceComparisonCell.self, forCellWithReuseIdentifier: FaceComparisonCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        cv.contentInsetAdjustmentBehavior = .automatic
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    // MARK: - Initialization

    /// PersonPageViewController를 생성합니다.
    ///
    /// - Parameters:
    ///   - personIndex: 표시할 인물 번호
    ///   - dataSource: 데이터 소스 (부모 뷰 컨트롤러)
    init(personIndex: Int, dataSource: FaceComparisonDataSource?) {
        self.personIndex = personIndex
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        setupCollectionView()
    }

    // MARK: - Setup

    /// 컬렉션 뷰 설정
    private func setupCollectionView() {
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Public Methods

    /// 컬렉션 뷰 리로드
    func reloadData() {
        collectionView.reloadData()
    }

    // MARK: - Helpers

    /// 디버그 텍스트 생성 (예: a1, a2, b1, b2)
    private func debugText(for indexPath: IndexPath) -> String {
        guard let dataSource = dataSource else { return "" }

        let personAlphabetIndex = dataSource.validPersonIndices.firstIndex(of: personIndex) ?? 0
        let personAlphabet = String(UnicodeScalar("a".unicodeScalars.first!.value + UInt32(personAlphabetIndex))!)
        return "\(personAlphabet)\(indexPath.item + 1)"
    }
}

// MARK: - UICollectionViewDataSource

extension PersonPageViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource?.photosForPerson(personIndex).count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FaceComparisonCell.reuseIdentifier,
            for: indexPath
        ) as? FaceComparisonCell else {
            return UICollectionViewCell()
        }

        guard let dataSource = dataSource else { return cell }

        let photos = dataSource.photosForPerson(personIndex)
        guard indexPath.item < photos.count else { return cell }

        let assetID = photos[indexPath.item]
        let isSelected = dataSource.isSelected(assetID)
        let debugText = debugText(for: indexPath)

        // 셀 재사용 안전장치: 현재 assetID 저장
        cell.currentAssetID = assetID

        // 이미지 로드 (비동기)
        dataSource.loadFaceImage(assetID: assetID, personIndex: personIndex) { [weak cell] image in
            // 셀 재사용 안전장치: assetID가 변경되었으면 무시
            guard cell?.currentAssetID == assetID else { return }

            DispatchQueue.main.async {
                cell?.configure(with: image, isSelected: isSelected, assetID: assetID, debugText: debugText)
            }
        }

        // 이미지 로드 전 placeholder 표시
        cell.configure(with: nil, isSelected: isSelected, assetID: assetID, debugText: debugText)

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension PersonPageViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let dataSource = dataSource else { return }

        let photos = dataSource.photosForPerson(personIndex)
        guard indexPath.item < photos.count else { return }

        let assetID = photos[indexPath.item]

        // 선택 토글 (부모에게 위임)
        dataSource.toggleSelection(for: assetID)

        // 셀 UI 업데이트
        if let cell = collectionView.cellForItem(at: indexPath) as? FaceComparisonCell {
            cell.setSelected(dataSource.isSelected(assetID))
        }

        Log.print("[PersonPageViewController] Toggled selection for \(assetID.prefix(8))...")
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PersonPageViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        // 2열 정사각형
        let width = (collectionView.bounds.width - Self.gridSpacing) / 2
        let size = max(width, Self.minCellSize)
        return CGSize(width: size, height: size)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(top: Self.gridSpacing, left: 0, bottom: Self.gridSpacing, right: 0)
    }
}
