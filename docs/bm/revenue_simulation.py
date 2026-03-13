#!/usr/bin/env python3
"""
SweepPic 33개월 매출 성장 시뮬레이션 v3
- 월별 복리 재투자 모델
- 수정 시 아래 PARAMETERS 섹션만 변경하면 됩니다
"""

# ============================================================
# PARAMETERS — 여기만 수정하세요
# ============================================================

# 사업 구조
GOV_BUDGET_PER_MONTH = 2_500_000   # 정부 광고비 (월, 원)
GOV_MONTHS = 9                      # 정부 지원 기간 (개월)
TOTAL_MONTHS = 33                   # 전체 시뮬레이션 기간
YEAR1_MONTHS = 9                    # 1년차 기간

# CPI (설치당 비용)
CPI_YEAR1 = 3100    # 1년차 CPI (원) — ASA국내30%+글로벌50%+릴스20%
CPI_YEAR2 = 2900    # 2년차~ CPI (원) — ASA국내30%+글로벌70%

# 구독 전환율
IOS_CONVERSION = 0.06       # iOS 전환율 (체험시작률 20% × Trial→Paid 26%)
ANDROID_CONVERSION = 0.03   # Android 전환율

# 구독 가격
MONTHLY_PRICE = 4400        # 월구독 가격 (원)
ANNUAL_PRICE = 29000        # 연구독 가격 (원)
MONTHLY_RATIO = 0.50        # 월구독 비율 (RevenueCat 2025 주간제외 재조정)
ANNUAL_RATIO = 0.50         # 연구독 비율

# 구독 갱신율
ANNUAL_RETENTION = 0.581    # 12개월 갱신율 (Photo & Video 중앙값, RevenueCat 2026)

# 광고 수익
AD_REV_PER_NONDAU_MONTH = 1500  # 비구독 DAU 1명당 월 광고수익 (원, ARPDAU $0.035)

# Apple 수수료 & 재투자
APPLE_COMMISSION = 0.15     # Apple Small Business Program 15%
REINVEST_RATE = 0.70        # 실수령액 중 재투자 비율

# 오가닉 성장 — ASO 오가닉 (월 설치 수)
ASO_ORGANIC_START = 100     # 1년차 시작 (PreApps: 인디 앱 60~150건 중앙)
ASO_ORGANIC_END_Y1 = 400   # 1년차 말
ASO_BOOST_Y2 = 1.36        # 2년차 ASO 최적화 효과 (+36%, ASO World)
ASO_BOOST_Y3 = 1.20        # 3년차 추가 개선 (+20%)

# 오가닉 성장 — 유료 부스트
PAID_BOOST_RATIO = 0.40    # 유료 설치의 40% (Digital Turbine ×1.5의 보수 적용)

# 오가닉 성장 — 자연 검색 유입
SEARCH_Y1_START = 150       # 1년차 시작 (월)
SEARCH_Y1_END = 310         # 1년차 말
SEARCH_Y2_START = 350
SEARCH_Y2_END = 680
SEARCH_Y3_START = 700
SEARCH_Y3_END = 975

# 바이럴 K (Amplitude: 실무 기준 0.15~0.25 "좋음")
VIRAL_K = {1: 0.15, 2: 0.20, 3: 0.25}

# Android (25개월차~)
ANDROID_START_MONTH = 25
ANDROID_INITIAL_RATIO = 0.30   # iOS 대비 시작 비율
ANDROID_MONTHLY_INCREASE = 0.05
ANDROID_MAX_RATIO = 0.60

# DAU 계산용
NON_SUB_MAU_RATIO = 0.02   # 전체 비구독 누적 설치 중 MAU 비율
DAU_MAU_RATIO = 0.10        # DAU/MAU (유틸리티 앱 10~15%)


# ============================================================
# SIMULATION — 아래는 수정 불필요
# ============================================================

def run_simulation():
    """33개월 월별 시뮬레이션 실행"""

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
        # 연차 판별
        if m <= YEAR1_MONTHS:
            year, ym = 1, m
        elif m <= YEAR1_MONTHS + 12:
            year, ym = 2, m - YEAR1_MONTHS
        else:
            year, ym = 3, m - YEAR1_MONTHS - 12

        cpi = CPI_YEAR1 if year == 1 else CPI_YEAR2

        # 광고비 = 정부지원 + 전월 매출 재투자
        gov = GOV_BUDGET_PER_MONTH if m <= GOV_MONTHS else 0
        reinvest = prev_revenue * (1 - APPLE_COMMISSION) * REINVEST_RATE if m > 1 else 0
        total_budget = gov + reinvest

        # 유료 설치
        paid = total_budget / cpi

        # ASO 오가닉
        if year == 1:
            max_ym = YEAR1_MONTHS
            aso = ASO_ORGANIC_START + (ASO_ORGANIC_END_Y1 - ASO_ORGANIC_START) * (ym - 1) / (max_ym - 1)
        elif year == 2:
            aso = ASO_ORGANIC_END_Y1 * ASO_BOOST_Y2
        else:
            aso = ASO_ORGANIC_END_Y1 * ASO_BOOST_Y2 * ASO_BOOST_Y3

        # 유료 부스트
        boost = paid * PAID_BOOST_RATIO

        # 자연 검색 유입
        if year == 1:
            search = SEARCH_Y1_START + (SEARCH_Y1_END - SEARCH_Y1_START) * (ym - 1) / (YEAR1_MONTHS - 1)
        elif year == 2:
            search = SEARCH_Y2_START + (SEARCH_Y2_END - SEARCH_Y2_START) * (ym - 1) / 11
        else:
            search = SEARCH_Y3_START + (SEARCH_Y3_END - SEARCH_Y3_START) * (ym - 1) / 11

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
    print("SweepPic 33개월 매출 시뮬레이션")
    print("=" * 80)

    # 핵심 파라미터
    print(f"\n📌 핵심 파라미터:")
    print(f"   가중 ARPU: ₩{arpu:,.0f}/월")
    print(f"   월간 유지율: {monthly_retention:.4f} ({monthly_retention*100:.2f}%)")
    print(f"   CPI: 1년차 ₩{CPI_YEAR1:,} / 2년차~ ₩{CPI_YEAR2:,}")
    print(f"   전환율: iOS {IOS_CONVERSION*100:.0f}% / Android {ANDROID_CONVERSION*100:.0f}%")
    print(f"   월:연 비율: {MONTHLY_RATIO*100:.0f}:{ANNUAL_RATIO*100:.0f}")
    print(f"   광고수익: ₩{AD_REV_PER_NONDAU_MONTH:,}/DAU/월")

    # 주요 월별 데이터
    print(f"\n{'─'*80}")
    print(f"{'월':>3} │{'연차':>4} │{'광고비':>8} │{'총설치':>7} │{'구독자':>6} │"
          f"{'구독매출':>8} │{'광고매출':>7} │{'총매출':>8} │{'누적매출':>10}")
    print(f"{'─'*80}")

    for r in results:
        if r['month'] in [1, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33]:
            print(f"{r['month']:3d} │ {r['year']}차 │ {r['budget']/10000:6.0f}만 │"
                  f" {r['total_installs']:5,.0f} │ {r['cum_subs']:4,.0f} │"
                  f" {r['sub_rev']/10000:6.1f}만 │ {r['ad_rev']/10000:5.1f}만 │"
                  f" {r['gross']/10000:6.1f}만 │ {r['cum_rev']/10000:8.1f}만")

    # 연도별 요약
    print(f"\n{'='*80}")
    print("연도별 요약")
    print(f"{'='*80}")

    for yr in [1, 2, 3]:
        d = [r for r in results if r['year'] == yr]
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
        print(f"  총 광고비:     {t_budget/10000:>8,.0f}만")
        print(f"  신규 설치:     {t_installs:>8,.0f}건")
        print(f"  누적 설치:     {c_installs:>8,.0f}건")
        print(f"  활성 구독자:   {subs:>8,.0f}명")
        print(f"  구독 매출:     {t_sub/10000:>8,.0f}만")
        print(f"  광고 매출:     {t_ad/10000:>8,.0f}만")
        print(f"  총매출 (Gross):{t_rev/10000:>8,.0f}만")
        print(f"  월말 매출:     {last/10000:>8.1f}만/월")
        print(f"  런레이트:      {last*12/10000:>8,.0f}만/년")

    # 성장률
    yr_data = {}
    for yr in [1, 2, 3]:
        d = [r for r in results if r['year'] == yr]
        yr_data[yr] = {
            'installs': sum(r['total_installs'] for r in d),
            'revenue': sum(r['gross'] for r in d),
            'subs': d[-1]['cum_subs']
        }

    print(f"\n성장률:")
    for prev, curr in [(1, 2), (2, 3)]:
        inst_g = (yr_data[curr]['installs'] / yr_data[prev]['installs'] - 1) * 100
        rev_g = (yr_data[curr]['revenue'] / yr_data[prev]['revenue'] - 1) * 100
        sub_g = (yr_data[curr]['subs'] / yr_data[prev]['subs'] - 1) * 100
        print(f"  {prev}→{curr}년차: 설치 +{inst_g:.0f}% | 매출 +{rev_g:.0f}% | 구독자 +{sub_g:.0f}%")


if __name__ == "__main__":
    results, arpu, monthly_retention = run_simulation()
    print_results(results, arpu, monthly_retention)
