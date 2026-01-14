# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# ⚠️ 중요: 모든 대화는 한글로 진행합니다

**이 저장소에서 작업할 때 Claude Code와의 모든 대화는 반드시 한글로 진행해야 합니다.**
**All conversations in this repository MUST be conducted in Korean.**

코드 작성, 설명, 질문, 답변 등 모든 커뮤니케이션을 한글로 해주세요.

# 사용자에 대한 호칭을 "사용자"라고 부른다.

---

## 프로젝트 개요

PickPhoto는 iOS 사진 갤러리 앱입니다. 네이티브 iOS 사진 앱과 유사한 경험을 제공하면서 빠른 사진 정리를 위한 생산성 기능을 추가하는 것을 목표로 합니다. 스와이프 삭제 제스처 등의 사진 정리를 간소화하는 특장점을 가지고 있습니다.

주요 기능 :
- 네이티브 사진 앱과 유사한 그리드 기반 사진 브라우징
- 사진 정리 특화 기능 보유(추후 상세 기능 명확화 예정)

## 언어 & 문서화

- **모든 대화와 설명은 한글로 작성**
- PRD 및 품질 문서는 한글로 작성됨
- 코드 식별자와 주석은 영어 사용
- 문서는 한글 권장

## 코딩 스타일

- **모든 코드에는 상세한 주석을 달아서 작성한다**
- **모든 파일은 1,000줄이 넘어가지 않도록 기능별로 파일을 분할해서 저장한다**

## 파일 삭제 규칙

- **임시파일 포함 모든 파일 삭제 작업은 사용자의 허락 없이 절대 하지 않는다**

## 분석/디버깅 규칙

- **분석 또는 원인 파악 요청 시, 사용자의 명시적 허락 없이 코드를 수정하지 않는다**

## Git 규칙

- **코드 수정을 50줄 이상 하게 될 경우 수정 전에 무조건 깃에 커밋하고 수정한다**
- **tasks.md의 각 페이즈 진행 전에 커밋하고, 진행후에도 커밋한다**
- **롤백 작업 요청 시 수동으로 코드를 수정하는 것을 기본으로 한다. 깃으로 롤백이 필요할 경우에는 사용자에게 확인을 받고 깃으로 롤백한다**
- **git checkout, git reset 등 git 명령어로 코드를 원복할 때는 반드시 본인(Claude)이 해당 대화에서 커밋한 경우에만 가능하다. 사용자가 커밋한 내용은 그 사이에 어떤 수정이 있었는지 알 수 없으므로 git으로 원복하지 않는다**

## Active Technologies (001-pickphoto-mvp)
- Swift 5.9+, iOS 16+
- UIKit 기반 (UICollectionView + performBatchUpdates)
- PhotoKit (PHAsset, PHFetchResult, PHCachingImageManager, PHPhotoLibraryChangeObserver)
- 파일 기반 저장 (앱 내 휴지통 상태)

## Recent Changes
- 002-similar-photo: Added Swift 5.9+ + UIKit, Vision Framework (VNGenerateImageFeaturePrintRequest, VNDetectFaceRectanglesRequest), PhotoKit (PHAsset, PHCachingImageManager)
- 001-similar-photo: Added Swift 5.9+ + UIKit, PhotoKit, Vision Framework
- 001-pickphoto-mvp: UIKit 기반 + performBatchUpdates + PHCachingImageManager 확정
