# Metric Reconciliation Notes

A reference for every metric where two different values appeared during this project for the same variable. In each case the values are arithmetically correct but computed on a different base, population, weighting, or data version. This note records which value is canonical for the dashboard and memo, and why.

The governing rule for the project, from the methodology note, is that all customer-facing metrics are filtered to delivered orders and use `customer_unique_id`. Where a base difference exists, the delivered, in-scope definition wins so the whole product stays internally consistent.

---

## A. Stale export versus live database

These differ only because the exported `fact_orders.parquet` was slightly behind the live MySQL `fact_orders` table.

### Early-delivery repeat lift, 31% versus 27%
- 31% from live MySQL, early return rate 3.05% over on-time 2.33%, (3.05 - 2.33) / 2.33.
- 27% from the stale parquet, 3.04% over 2.40%.
- The whole gap is one customer. On-time had 29 of 1,247 returning customers live (2.33%) versus 30 of 1,248 in the parquet (2.40%). Because the denominator is tiny, one extra returner swings the lift from 31% to 27%.
- **Use 31%.** Live MySQL is canonical. Regenerate the parquet from the live database to remove the disagreement.

### On-time first-delivery return rate, 2.33% versus 2.40%
- Same root cause as above, 29 of 1,247 (live) versus 30 of 1,248 (stale parquet).
- **Use 2.33%.**

---

## B. Different population or denominator

Same metric, different set of rows in the denominator.

### Repeat purchase rate, 3.0% versus 3.12%
- 3.0% is 2,801 repeat customers over the 93,358 delivered RFM customers.
- 3.12% is 2,997 repeat customers over the full raw customer table of 96,096, which includes roughly 2,700 customers whose orders were never delivered. This came from the archived pandas-only EDA notebook, before the delivered filter and the fact_orders build.
- **Use 3.0%.** The dashboard shows "93K Total Customers" and the entire RFM analysis runs on the 93,358 delivered base, so the rate must use the same base or its denominator silently disagrees with the customer count beside it.

### Total customers, 93,358 (93K) versus 96,096 (96K)
- 93,358 is the delivered RFM base, 96,096 is all raw customers.
- **Use 93,358.** Same reasoning as the repeat rate, this is the base for all customer metrics.

### Severely-late negative review rate, 75% versus 73%
- 74.7%, rounds to 75%, is the share of 1 to 2 star reviews among late-4-plus orders that have a review.
- 72.6%, rounds to 73%, uses all late-4-plus orders including those with no review in the denominator.
- **Use 75%.** The standard denominator is orders that received a review, which is also what the `pct_negative` field in `agg_review_by_delivery_bucket` reports.

### Fix Experience and Invest More revenue share, 35% and 29% versus 35.3% and 29.1%
- 35% (34.9%) and 29% (28.8%) divide each quadrant by all 73 categories, 15.22M, the Page 3 KPI framing and the README headline.
- 35.3% and 29.1% divide by the 52 categorised in-scope categories, 15.05M, the Page 1 donut. A donut must sum to 100%, so it can only use the categorised total.
- **Use the all-revenue framing, 35% and 29%, as the headline.** The donut is necessarily "share of categorised revenue." Round the donut to whole numbers and understand it excludes the 21 uncategorised categories.

---

## C. Different weighting or grain

Same metric, different aggregation method.

### Review benchmark line, 4.08 versus 4.11
- 4.08 (4.0819) is the marketplace average review per order, order-weighted across all delivered orders. Used on the Page 4 bucket chart and the state map.
- 4.11 (4.105769) is the average review per category, an unweighted mean of the 52 in-scope categories' review scores. Used as the Page 3 scatter divider, and it is the exact value the quadrant column was built on.
- **Both are correct for their visual.** Label them distinctly, "Marketplace avg 4.08" and "Avg category rating 4.11," so they do not look like an error. The scatter line must stay 4.11 or the bubble colours and the divider would disagree.

### Average delivery days, 12.5 versus 12.6 versus 12.1
- 12.5 is the order or item weighted `total_days` from the decomposition table, used on the dashboard.
- 12.6 (12.58) is the notebook purchase-to-delivered mean over all delivered orders.
- 12.1 is the mean of the `delivery_days_total` field.
- These differ by definition and grain, all within half a day. **Use 12.5** on the dashboard, since it comes from the same source as the 74% transit-share KPI and stays consistent with it.

### Decomposition weighting grain, item grain versus order grain
- The phase-day averages in `agg_delivery_decomposition` were computed item-grain, `COUNT(*)` over `fact_orders`, giving early 101,460.
- The deduped order-grain counts are early 88,163, or 87,528 with the full timestamp filters.
- **Weight by the item-grain counts** because that is the grain the phase averages were computed at. Mixing order-grain weights with item-weighted averages is inconsistent. Either way the KPI rounds to 12.5 days and 74%.

### Early delivery order count, 87,528 versus 88,644
- 87,528 from the notebook SQL, which requires all four timestamps to be non-null and all phase durations non-negative.
- 88,644 is the order-level early count without those filters.
- **Use 87,528** for any figure tied to the decomposition, since it shares those filters.

---

## D. Noise filtering and scope

### Worst-rated category, 3.52 versus 2.50
- 3.52 is office_furniture, the lowest review among in-scope categories with at least 30 orders in the prior period.
- 2.50 is security_and_services, the absolute lowest, but it has only 324 BRL of revenue and a handful of orders, so its average is statistical noise.
- **Use 3.52.** Filter the KPI to `orders_prior_6m >= 30` so tiny categories with unreliable averages cannot take the spot. Label it "Lowest Rated Major Category" so the exclusion is clear.

### Growth Leaders, meaningful categories versus small-base spikes
- Without a revenue floor the fastest growers were tiny categories, signaling_and_security at 275% on 28K revenue, food at 198% on 36K.
- With a revenue floor (total revenue at least 100K, or `orders_prior_6m >= 200`), the leaders become housewares, health_beauty, pet_shop, the real opportunities.
- **Apply the revenue floor.** Percent growth on a small base is not a commercial opportunity.

---

## E. Aggregation artifacts

### Total product categories, 73 versus 74
- 73 from `agg_category_performance`, which excludes the null or untranslated category.
- 74 from a distinct count of `product_category` on `fact_orders`, which includes one extra.
- **Use 73**, the categorised count the rest of the category analysis uses.

---

## Summary table

| Metric | Values seen | Canonical | Reason |
|---|---|---|---|
| Repeat rate | 3.0% vs 3.12% | 3.0% | 93,358 delivered base, not 96,096 raw |
| Total customers | 93K vs 96K | 93,358 | delivered RFM base |
| One-time customer revenue | 94% vs 99% | 94% rev, 97% of customers | 99% was unbacked |
| Early repeat lift | 31% vs 27% | 31% | live MySQL, not stale parquet |
| On-time return rate | 2.33% vs 2.40% | 2.33% | live MySQL |
| Late-4+ negative reviews | 75% vs 73% | 75% | denominator is reviewed orders |
| Fix Experience share | 35% vs 35.3% | 35% | of all revenue, not categorised only |
| Invest More share | 29% vs 29.1% | 29% | of all revenue, not categorised only |
| Review benchmark | 4.08 vs 4.11 | both, labelled | order-weighted vs per-category mean |
| Avg delivery days | 12.5 vs 12.6 vs 12.1 | 12.5 | matches transit-share source |
| Early order count | 87,528 vs 88,644 | 87,528 | full timestamp filters |
| Worst category review | 3.52 vs 2.50 | 3.52 | excludes noise categories |
| Total categories | 73 vs 74 | 73 | excludes null category |
