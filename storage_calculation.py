#!/usr/bin/env python3
"""사진 5만장 저장 공간 계산기"""

photo_formats = {
    "HEIC 일반": {"mb": 3, "desc": "iPhone 12 이후 표준 사진"},
    "JPEG 일반": {"mb": 4.5, "desc": "구버전 iPhone 사진"},
    "Live Photo": {"mb": 5.5, "desc": "Live Photo (HEIC+영상)"},
    "ProRAW": {"mb": 40, "desc": "ProRAW 포맷"},
}

photo_counts = {
    "일반 사용자": {"HEIC": 0.8, "JPEG": 0.15, "Live": 0.04, "ProRAW": 0.01},
    "사진가": {"HEIC": 0.6, "JPEG": 0.1, "Live": 0.2, "ProRAW": 0.1},
    "최대 용량": {"HEIC": 0.4, "JPEG": 0.1, "Live": 0.1, "ProRAW": 0.4}
}

def calculate_storage(profile_name, ratios):
    print(f"\n## {profile_name} 프로필")
    total_mb = 0
    details = []

    heic_count = int(50000 * ratios["HEIC"])
    jpeg_count = int(50000 * ratios["JPEG"])
    live_count = int(50000 * ratios["Live"])
    proraw_count = 50000 - heic_count - jpeg_count - live_count

    if heic_count > 0:
        heic_mb = heic_count * photo_formats["HEIC 일반"]["mb"]
        total_mb += heic_mb
        details.append(f"HEIC {heic_count:,}장: {heic_mb:,}MB")

    if jpeg_count > 0:
        jpeg_mb = jpeg_count * photo_formats["JPEG 일반"]["mb"]
        total_mb += jpeg_mb
        details.append(f"JPEG {jpeg_count:,}장: {jpeg_mb:,}MB")

    if live_count > 0:
        live_mb = live_count * photo_formats["Live Photo"]["mb"]
        total_mb += live_mb
        details.append(f"Live Photo {live_count:,}장: {live_mb:,}MB")

    if proraw_count > 0:
        proraw_mb = proraw_count * photo_formats["ProRAW"]["mb"]
        total_mb += proraw_mb
        details.append(f"ProRAW {proraw_count:,}장: {proraw_mb:,}MB")

    total_gb = total_mb / 1024

    print(f"사진 구성:")
    for detail in details:
        print(f"  - {detail}")
    print(f"총 용량: {total_mb:,}MB ({total_gb:.1f}GB)")

    # iOS 시스템 여유 공간 추가 (약 20%)
    ios_reserve = total_gb * 0.2
    total_with_reserve = total_gb + ios_reserve
    print(f"iOS 여유 공간 포함: {total_with_reserve:.1f}GB (+{ios_reserve:.1f}GB)")

    return total_with_reserve

# 각 프로필 계산
print("=" * 60)
print("사진 5만장 저장 공간 시뮬레이션")
print("=" * 60)

for profile_name, ratios in photo_counts.items():
    calculate_storage(profile_name, ratios)

print("\n" + "=" * 60)
print("추가 고려사항:")
print("- 앱 설치 공간: 1-2GB")
print("- 캐시 및 임시 파일: 3-5GB")
print("- iOS 시스템: 10-15GB")
print("- 다른 앱 및 데이터: 사용자별 상이")
print("=" * 60)