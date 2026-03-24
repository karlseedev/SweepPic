#!/usr/bin/env python3
"""
SweepPic 매출 시뮬레이션 — Plan A
- 예비창업패키지 4,000만원 예산 기준
- 협약기간: 10개월 (4월~1월)
- CPI 광고비: 1,400만원 (정부) + 1,400만원 (사비) = 2,800만원
- 58개월 (1년차 10개월 + 2~5년차 각 12개월)
- 수정 시 아래 PARAMETERS 섹션만 변경하면 됩니다
"""

# ============================================================
# PARAMETERS — 여기만 수정하세요
# ============================================================

# 사업 구조
TOTAL_MONTHS = 58                   # 1년차 10개월 + 2~5년차 12개월×4
YEAR1_MONTHS = 10                   # 협약기간 10개월 (4~1월)

# CPI — 채널 비중 (ASA한국52% + ASA글로벌33% + 인스타15%)
CPI_YEAR1 = 2600    # 0.52×1500 + 0.33×3500 + 0.15×4500
CPI_YEAR2 = 2700    # 2년차~ ASA 최적화

# 구독 전환율
IOS_CONVERSION = 0.05       # iOS 전환율 (체험시작률 20% × Trial→Paid 26%)
ANDROID_CONVERSION = 0.015  # Android 전환율 (iOS의 30%, Photo 카테고리 iOS 편중 반영)

# 구독 가격
MONTHLY_PRICE = 4400        # 월구독 가격 (원)
ANNUAL_PRICE = 29000        # 연구독 가격 (원)
MONTHLY_RATIO = 0.50        # 월구독 비율
ANNUAL_RATIO = 0.50         # 연구독 비율

# 구독 갱신율
ANNUAL_RETENTION = 0.581    # 12개월 갱신율 (Photo & Video 중앙값, RevenueCat 2026)

# 광고 수익
AD_REV_PER_NONDAU_MONTH = 1500  # 비구독 DAU 1명당 월 광고수익 (원, ARPDAU $0.035)

# Apple 수수료 & 재투자
APPLE_COMMISSION = 0.15     # Apple Small Business Program 15%
REINVEST_RATE = {1: 0.70, 2: 0.70, 3: 0.70, 4: 0.60, 5: 0.50}  # 연차별 재투자율

# 오가닉 성장 — ASO 오가닉
ASO_ORGANIC_START = 100     # 1년차 시작 (PreApps: 인디 앱 60~150건 중앙)
ASO_ORGANIC_END_Y1 = 400    # 1년차 말
ASO_BOOST_Y2 = 1.36         # 2년차 ASO 최적화 효과 (+36%, ASO World)
ASO_BOOST_Y3 = 1.20         # 3년차 추가 개선 (+20%)
# 4~5년차: 연 +10%씩 점진 성장

# 오가닉 성장 — 유료 부스트
PAID_BOOST_RATIO = 0.65     # Digital Turbine ×1.5 (50%) + 인스타 브랜드 효과 (15%p)

# 오가닉 성장 — 자연 검색 유입
SEARCH_Y1_START = 150
SEARCH_Y1_END = 310
SEARCH_Y2_START = 350
SEARCH_Y2_END = 680
SEARCH_Y3_START = 700
SEARCH_Y3_END = 975
# 4~5년차: 3년차 말 기준 연 +10%씩

# 바이럴 K (Amplitude: 실무 기준 0.15~0.25 "좋음")
VIRAL_K = {1: 0.15, 2: 0.25, 3: 0.30, 4: 0.32, 5: 0.35}

# Android (1년차 9개월차 = 12월 출시, 개발기간 8~12월)
ANDROID_START_MONTH = 9      # 1년차 9개월차 (12월) Android 출시
ANDROID_INITIAL_RATIO = 0.30
ANDROID_MONTHLY_INCREASE = 0.05
ANDROID_MAX_RATIO = 0.40

# DAU 계산용
NON_SUB_MAU_RATIO = 0.03    # 전체 비구독 누적 설치 중 MAU 비율 (업계 평균)
DAU_MAU_RATIO = 0.20        # DAU/MAU (업계 평균 20%)


# ============================================================
# 광고비 — 오픈 초집중 + 사비 앞집중
# Plan A: 정부 광고선전비 1,800만 + 사비 1,400만 = 3,200만
# 정부 CPI(ASA+인스타): 1,400만 / ASO+콘텐츠: 400만 (간접비)
# 사비 CPI: 1,400만 (8월 초집중 → 점감)
# ============================================================

# 채널별 CPI
CPI_ASA_KR = 2_576      # ASA 한국 ($1.84 × ₩1,400, AppTweak 2025)
CPI_ASA_GLOBAL = 5_684   # ASA 글로벌 ($4.06 × ₩1,400, AppTweak 2025 미국)
CPI_INSTA = 5_950        # 인스타그램 릴스 ($4.25 × ₩1,400, Wask 2025 중간값)

# 월별 채널별 광고비 배분 (한국, 글로벌, 인스타) — 단위: 원
# ASO·콘텐츠는 간접비 → CPI 계산에 미포함, 오가닉 파라미터로 반영
AD_BUDGET_BY_MONTH = {
    # (ASA한국, ASA글로벌, 인스타)
    1: (        0,         0,         0),   # 4월: 소프트 론칭 (뉴질랜드)
    2: (        0,         0,         0),   # 5월: 준비
    3: (4_000_000,   500_000,   500_000),   # 6월: 한국 론칭 (ASA 한국 집중) — 정부
    4: (1_500_000, 6_000_000, 1_500_000),   # 7월: 글로벌 론칭 (초집중) — 정부
    5: (2_000_000, 5_000_000,         0),   # 8월: 사비 700만 (앞집중)
    6: (1_000_000, 3_000_000,         0),   # 9월: 사비 400만
    7: (  500_000, 1_000_000,         0),   # 10월: 사비 150만
    8: (        0,   500_000,         0),   # 11월: 사비 50만
    9: (        0,   500_000,         0),   # 12월: 사비 50만
   10: (        0,   500_000,         0),   # 1월: 사비 50만
}
# 정부 CPI: ASA한국 550만 + ASA글로벌 650만 + 인스타 200만 = 1,400만 (6~7월)
# 사비 CPI: 700+400+150+50+50+50 = 1,400만 (8~1월, 앞집중)

def gov_budget(month):
    """월별 총 광고비 반환"""
    if month in AD_BUDGET_BY_MONTH:
        return sum(AD_BUDGET_BY_MONTH[month])
    return 0

def calc_paid_installs(month, total_budget):
    """채널별 CPI로 분리 계산하여 유료 설치 수 반환
    1년차: 채널별 비율에 따라 분리 계산
    2년차~: 재투자분은 최적화된 CPI(₩2,700)로 계산
    """
    if month in AD_BUDGET_BY_MONTH:
        kr, gl, insta = AD_BUDGET_BY_MONTH[month]
        gov_total = kr + gl + insta
        # 정부/사비 예산은 채널별 분리 계산
        paid_from_channels = 0
        if kr > 0:
            paid_from_channels += kr / CPI_ASA_KR
        if gl > 0:
            paid_from_channels += gl / CPI_ASA_GLOBAL
        if insta > 0:
            paid_from_channels += insta / CPI_INSTA
        # 재투자분은 최적화된 CPI로 계산
        reinvest_amount = total_budget - gov_total
        if reinvest_amount > 0:
            paid_from_reinvest = reinvest_amount / CPI_YEAR2
            return paid_from_channels + paid_from_reinvest
        return paid_from_channels
    else:
        # 2년차~: 전부 재투자, 최적화된 CPI
        return total_budget / CPI_YEAR2


# ============================================================
# SIMULATION — 아래는 수정 불필요
# ============================================================

def run_simulation():
    """58개월 월별 시뮬레이션 실행"""

    # 파생 파라미터
    arpu = MONTHLY_RATIO * MONTHLY_PRICE + ANNUAL_RATIO * (ANNUAL_PRICE / 12)
    monthly_retention = ANNUAL_RETENTION ** (1/12)

    # 상태 변수
    cum_installs = 0
    cum_subs = 0
    cum_revenue = 0
    prev_revenue = 0
    results = []

    for m in range(1, TOTAL_MONTHS + 1):
        # 연차 판별 (1년차 10개월 + 2~5년차 각 12개월)
        if m <= YEAR1_MONTHS:
            year, ym = 1, m
        else:
            elapsed = m - YEAR1_MONTHS
            year = 2 + (elapsed - 1) // 12
            ym = (elapsed - 1) % 12 + 1

        # 광고비 = 정부지원/사비 + 전월 매출 재투자
        gov = gov_budget(m)
        reinvest = prev_revenue * (1 - APPLE_COMMISSION) * REINVEST_RATE[year] if m > 1 else 0
        total_budget = gov + reinvest

        # 유료 설치 — 채널별 CPI 분리 계산
        paid = calc_paid_installs(m, total_budget)

        # ASO 오가닉 (4~5년차는 3년차 대비 연 +10%씩)
        if year == 1:
            max_ym = YEAR1_MONTHS
            aso = ASO_ORGANIC_START + (ASO_ORGANIC_END_Y1 - ASO_ORGANIC_START) * (ym - 1) / max(max_ym - 1, 1)
        elif year == 2:
            aso = ASO_ORGANIC_END_Y1 * ASO_BOOST_Y2
        elif year == 3:
            aso = ASO_ORGANIC_END_Y1 * ASO_BOOST_Y2 * ASO_BOOST_Y3
        else:
            aso = ASO_ORGANIC_END_Y1 * ASO_BOOST_Y2 * ASO_BOOST_Y3 * (1.10 ** (year - 3))

        # 유료 부스트
        boost = paid * PAID_BOOST_RATIO

        # 자연 검색 유입 (4~5년차는 3년차 말 기준 연 +10%씩)
        if year == 1:
            search = SEARCH_Y1_START + (SEARCH_Y1_END - SEARCH_Y1_START) * (ym - 1) / max(YEAR1_MONTHS - 1, 1)
        elif year == 2:
            search = SEARCH_Y2_START + (SEARCH_Y2_END - SEARCH_Y2_START) * (ym - 1) / 11
        elif year == 3:
            search = SEARCH_Y3_START + (SEARCH_Y3_END - SEARCH_Y3_START) * (ym - 1) / 11
        else:
            search = SEARCH_Y3_END * (1.10 ** (year - 3))

        # 바이럴
        k = VIRAL_K[year]
        base = paid + aso + boost + search
        viral = base * k / (1 - k)

        ios_installs = base + viral

        # Android
        if m >= ANDROID_START_MONTH:
            android_ratio = min(
                ANDROID_INITIAL_RATIO + ANDROID_MONTHLY_INCREASE * (m - ANDROID_START_MONTH),
                ANDROID_MAX_RATIO
            )
        else:
            android_ratio = 0
        android_installs = ios_installs * android_ratio
        total_installs = ios_installs + android_installs
        cum_installs += total_installs

        # 신규 구독자
        new_subs = ios_installs * IOS_CONVERSION + android_installs * ANDROID_CONVERSION

        # 누적 구독자 (이탈 반영)
        cum_subs = cum_subs * monthly_retention + new_subs

        # 구독 매출 (Gross)
        sub_rev = cum_subs * arpu

        # 광고 매출
        non_sub_mau = (cum_installs - cum_subs) * NON_SUB_MAU_RATIO
        non_sub_dau = non_sub_mau * DAU_MAU_RATIO
        ad_rev = non_sub_dau * AD_REV_PER_NONDAU_MONTH

        # 총매출
        gross = sub_rev + ad_rev
        cum_revenue += gross
        prev_revenue = gross

        results.append({
            'month': m, 'year': year, 'budget': total_budget,
            'gov': gov, 'reinvest': reinvest,
            'paid': paid, 'organic': aso + boost + search, 'viral': viral,
            'android': android_installs,
            'total_installs': total_installs, 'cum_installs': cum_installs,
            'new_subs': new_subs, 'cum_subs': cum_subs,
            'sub_rev': sub_rev, 'ad_rev': ad_rev,
            'gross': gross, 'cum_rev': cum_revenue
        })

    return results, arpu, monthly_retention


def print_results(results, arpu, monthly_retention):
    """결과 출력"""

    print("=" * 80)
    print("SweepPic 매출 시뮬레이션 — Plan A")
    print(f"총 기간: {TOTAL_MONTHS}개월 | 정부 CPI 광고비: 1,400만 + 사비 1,400만 (10개월)")
    print(f"예산 기준: 예비창업패키지 4,000만원 (광고선전비 1,800만) + 사비 1,400만")
    print("=" * 80)

    # 핵심 파라미터
    print(f"\n핵심 파라미터:")
    print(f"   가중 ARPU: ₩{arpu:,.0f}/월")
    print(f"   월간 유지율: {monthly_retention:.4f} ({monthly_retention*100:.2f}%)")
    print(f"   CPI: 1년차 ₩{CPI_YEAR1:,} (가중평균) / 2년차~ ₩{CPI_YEAR2:,}")
    print(f"   전환율: iOS {IOS_CONVERSION*100:.0f}% / Android {ANDROID_CONVERSION*100:.0f}%")
    print(f"   재투자율: 1~3년차 {REINVEST_RATE[1]*100:.0f}% / 4년차 {REINVEST_RATE[4]*100:.0f}% / 5년차 {REINVEST_RATE[5]*100:.0f}%")
    print(f"   유료부스트: {PAID_BOOST_RATIO*100:.0f}% (Digital Turbine ×1.5)")
    print(f"   광고수익: ₩{AD_REV_PER_NONDAU_MONTH:,}/DAU/월")

    # 광고비 배분
    gov_total = sum(r['gov'] for r in results)
    print(f"\n광고비 배분 (오픈 초집중 + 사비 앞집중):")
    print(f"   소프트론칭 (4~5월): 0원")
    print(f"   한국 론칭 (6월): 550만 (정부)")
    print(f"   글로벌 론칭 (7월): 900만 (정부)")
    print(f"   사비 앞집중 (8월): 700만 → 점감")
    print(f"   합계: {gov_total/10000:,.0f}만 (정부CPI 1,400만 + 사비 1,400만)")

    # 주요 월별 데이터
    milestones = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58]

    print(f"\n{'─'*90}")
    print(f"{'월':>3} │{'연차':>4} │{'광고비':>8} │{'총설치':>7} │{'구독자':>7} │"
          f"{'구독매출':>8} │{'광고매출':>7} │{'총매출':>8} │{'누적매출':>10}")
    print(f"{'─'*90}")

    for r in results:
        if r['month'] in milestones:
            print(f"{r['month']:3d} │ {r['year']}차 │ {r['budget']/10000:6.0f}만 │"
                  f" {r['total_installs']:6,.0f} │ {r['cum_subs']:6,.0f} │"
                  f" {r['sub_rev']/10000:6.1f}만 │ {r['ad_rev']/10000:5.1f}만 │"
                  f" {r['gross']/10000:6.1f}만 │ {r['cum_rev']/10000:8.1f}만")

    # 연도별 요약
    print(f"\n{'='*80}")
    print("연도별 요약")
    print(f"{'='*80}")

    for yr in [1, 2, 3, 4, 5]:
        d = [r for r in results if r['year'] == yr]
        if not d:
            continue
        months = len(d)
        t_budget = sum(r['budget'] for r in d)
        t_installs = sum(r['total_installs'] for r in d)
        c_installs = d[-1]['cum_installs']
        subs = d[-1]['cum_subs']
        t_sub = sum(r['sub_rev'] for r in d)
        t_ad = sum(r['ad_rev'] for r in d)
        t_rev = sum(r['gross'] for r in d)
        last = d[-1]['gross']

        print(f"\n{yr}년차 ({months}개월):")
        print(f"  총 광고비:     {t_budget/10000:>10,.0f}만")
        print(f"  신규 설치:     {t_installs:>10,.0f}건")
        print(f"  누적 설치:     {c_installs:>10,.0f}건")
        print(f"  활성 구독자:   {subs:>10,.0f}명")
        print(f"  구독 매출:     {t_sub/10000:>10,.0f}만")
        print(f"  광고 매출:     {t_ad/10000:>10,.0f}만")
        print(f"  총매출 (Gross):{t_rev/10000:>10,.0f}만")
        print(f"  월말 매출:     {last/10000:>10.1f}만/월")
        print(f"  런레이트:      {last*12/10000:>10,.0f}만/년")

    # 성장률
    yr_data = {}
    for yr in [1, 2, 3, 4, 5]:
        d = [r for r in results if r['year'] == yr]
        if d:
            yr_data[yr] = {
                'installs': sum(r['total_installs'] for r in d),
                'revenue': sum(r['gross'] for r in d),
                'subs': d[-1]['cum_subs']
            }

    print(f"\n성장률:")
    for prev, curr in [(1, 2), (2, 3), (3, 4), (4, 5)]:
        if prev in yr_data and curr in yr_data:
            inst_g = (yr_data[curr]['installs'] / yr_data[prev]['installs'] - 1) * 100
            rev_g = (yr_data[curr]['revenue'] / yr_data[prev]['revenue'] - 1) * 100
            sub_g = (yr_data[curr]['subs'] / yr_data[prev]['subs'] - 1) * 100
            print(f"  {prev}→{curr}년차: 설치 +{inst_g:.0f}% | 매출 +{rev_g:.0f}% | 구독자 +{sub_g:.0f}%")


if __name__ == "__main__":
    results, arpu, monthly_retention = run_simulation()
    print_results(results, arpu, monthly_retention)
