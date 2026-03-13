//
//  ExtendedFallbackTester.swift
//  PickPhoto
//
//  Created on 2026-01-18.
//
//  Vision Fallback 테스트 도구 — Vision FaceDetector 제거로 비활성화됨
//  YuNet 960이 Vision을 대체하여 더 이상 비교 테스트 불필요

import Foundation
import Photos

#if DEBUG

class ExtendedFallbackTester {
    static let shared = ExtendedFallbackTester()
    private init() {}

    /// Vision fallback 비교 테스트 (비활성화됨)
    func runComparison(with photos: [PHAsset]) async {
        print("[Debug] ExtendedFallbackTester 비활성화됨 (Vision FaceDetector 제거)")
    }
}

#endif
