# Cafe Product Sales Performance — Requirements

## 1. Purpose

The cafe owner wants a clear, repeatable view of how each product sells over time: which items bring in the most money, which move the most units, how sales build up through the year, and how customers buy (payment method, in-store vs. takeaway). This document defines the questions to answer, the metrics and their exact calculations (including cumulative sums), and what the finished analysis must deliver.

## 2. Stakeholder

| Role | Need |
|---|---|
| Cafe owner | Decide what to promote, stock, reprice, or drop; track progress toward revenue goals through the year. |

## 3. Data Source

**Raw table:** `cafe_sales`
**Cleaning script:** `cafe_sales_data_cleaning.sql` (Postgres; see 3.1)
**Cleaned file:** `cafe_sales_cleaned` (CSV export of table `cafe_sales_cleaned`)
**Rows:** 9,974 transactions (26 of 10,000 raw rows removed in cleaning; see 3.1)
**Period:** 2023-01-01 to 2023-12-31 (460 rows have no date)
**Total revenue:** $89,042.00
**Grain:** one row = one transaction of a single item

| Column | Type | Description | Values seen |
|---|---|---|---|
| `transaction_id` | string | Unique transaction key | `TXN_xxxxxxx`, all unique |
| `item` | string | Product sold | Cake, Coffee, Cookie, Juice, Salad, Sandwich, Smoothie, Tea; no NULLs |
| `quantity` | int | Units in the transaction | 1–5; no NULLs |
| `price_per_unit` | numeric(10,1) | Unit price | 1.0–5.0 (one fixed price per item); no NULLs |
| `total_spent` | numeric | Transaction revenue | 1.00–25.00; no NULLs |
| `payment_method` | string | How the customer paid | Cash, Credit Card, Digital Wallet; NULL = unknown |
| `location` | string | Order type | In-store, Takeaway; NULL = unknown |
| `transaction_date` | date | Sale date | `YYYY-MM-DD`; NULL = unknown |

The four sales columns (`item`, `quantity`, `price_per_unit`, `total_spent`) are complete. `payment_method`, `location`, and `transaction_date` keep NULL where the value was missing, rather than being filled with a default, so no sales are assigned to the wrong category.

Unit prices observed: Cookie 1.00, Tea 1.50, Coffee 2.00, Cake 3.00, Juice 3.00, Sandwich 4.00, Smoothie 4.00, Salad 5.00.

### 3.1 Cleaning process

**Raw data profile (before cleaning).** Every column was stored as text. Besides true NULLs, several columns contained the placeholder strings `UNKNOWN` and `ERROR`.

| Column | True NULLs in raw data | Also contained |
|---|---|---|
| `transaction_id` | 0 | — (10,000 unique) |
| `item` | 333 | `UNKNOWN`, `ERROR` |
| `quantity` | 138 | `UNKNOWN`, `ERROR` |
| `price_per_unit` | 179 | `UNKNOWN`, `ERROR` |
| `total_spent` | 173 | `UNKNOWN`, `ERROR` |
| `payment_method` | 2,579 | `UNKNOWN`, `ERROR` |
| `location` | 3,265 | `UNKNOWN`, `ERROR` |
| `transaction_date` | 159 | `UNKNOWN`, `ERROR` |

**Steps in `cafe_sales_data_cleaning.sql`**

| Step | Action |
|---|---|
| 1–3 | Profile the raw table: NULL counts, distinct values, and a search for odd characters (all pattern matches, such as `1.5` and `Credit Card`, were valid values). |
| 4 | Copy `cafe_sales` into a temp table so the raw data is never modified. |
| 5 | Convert `UNKNOWN` and `ERROR` to NULL in every column. |
| 6 | Cast types: `price_per_unit` → numeric(10,1), `total_spent` → numeric, `quantity` → int, `transaction_date` → date. |
| 7 | Fill missing `price_per_unit` as `total_spent / quantity` where both are known. |
| 8 | Fill missing `item` from `price_per_unit`: $1 Cookie, $1.50 Tea, $2 Coffee, $3 Cake, $4 Smoothie, $5 Salad (see Assumptions for $3 and $4). |
| 9 | Standardize `price_per_unit` from `item` (one fixed price per item). |
| 10 | Fill missing `quantity` as `total_spent / price_per_unit` and missing `total_spent` as `quantity × price_per_unit`. |
| 11 | Delete rows where `total_spent` or `item` is still NULL. |
| 12 | Confirm no rows with NULL `total_spent` remain. |
| 13–14 | Save the result as table `cafe_sales_cleaned` and review it. |

Each fill step runs as its own `UPDATE`, so every step uses the values corrected by the step before it (for example, Step 8 can assign an item from a price that Step 7 derived).

`payment_method`, `location`, and `transaction_date` are left NULL when missing. These gaps are too large (about a third of rows for payment and location) to fill with a default without distorting the results.

**Rows removed in Step 11.** 26 rows could not be recovered: 6 had no item and no price, and 23 had neither quantity nor total (3 rows had both problems). Together they held $54.00 of recorded revenue (0.06%), all on rows with an unknown item.

## 4. Business Questions

### 4.1 Product performance
1. Which products generate the most and least **revenue**?
2. Which products sell the most and least **units**?
3. What share of total revenue does each product contribute?
4. What is the **average transaction value** and **average quantity per transaction** for each product?
5. Which products are high-volume but low-revenue (and vice versa)?

### 4.2 Trends over time
6. How do revenue and units change **by month**, **by week**, and **by day of week**?
7. Which products are growing or declining month over month?
8. Are there seasonal patterns (e.g. cold drinks in summer, hot drinks in winter)?

### 4.3 Cumulative performance (running totals)
9. How does **year-to-date revenue** build up day by day and month by month?
10. How does each product's **cumulative revenue** compare over the year — when does one product overtake another?
11. When did the cafe (and each product) cross revenue milestones (e.g. 25%, 50%, 75% of annual revenue, or fixed targets like $25k / $50k / $75k)?
12. Which small set of products makes up most of the revenue (**cumulative share / Pareto 80/20**)?

### 4.4 Customer behavior
13. What is the revenue and transaction split by **payment method**, overall and per product?
14. What is the split between **In-store** and **Takeaway**, overall and per product?
15. Do some products sell mainly as takeaway?

## 5. Metric Definitions

| Metric | Definition |
|---|---|
| Revenue | `SUM(total_spent)` |
| Units sold | `SUM(quantity)` |
| Transactions | `COUNT(transaction_id)` |
| Average transaction value (ATV) | `Revenue / Transactions` |
| Average units per transaction | `Units sold / Transactions` |
| Revenue share | `Product revenue / Total revenue` |
| Month-over-month growth | `(Revenue this month − Revenue last month) / Revenue last month` |

**NULL handling for metrics**
- `item`, `quantity`, `price_per_unit`, and `total_spent` have no NULLs after cleaning, so revenue, units, ATV, and product totals use every row and product revenue adds up to total revenue.
- NULLs remain only in `payment_method`, `location`, and `transaction_date`; see sections 6 and 7 for how they are handled.

## 6. Cumulative Sum Requirements

All cumulative sums are **running totals ordered by date** (ascending) unless stated otherwise. The ordering and grouping must be explicit so results are reproducible.

### 6.1 Cumulative revenue — whole cafe
- **Daily running total:** aggregate revenue per day, then take the cumulative sum across days.
- **Monthly running total:** aggregate revenue per month, then take the cumulative sum across months.
- Days with no sales must still appear (with 0 revenue) so the running total line has no gaps.
- Rows with NULL `transaction_date` are **excluded** from all running totals (they cannot be placed in time). Their revenue ($4,173.50, 4.7% of total) is reported separately as "Undated".

```python
dated = df[df["transaction_date"].notna()]
daily = (dated.groupby("transaction_date")["total_spent"].sum()
           .asfreq("D", fill_value=0))
daily_cum = daily.cumsum()
```

### 6.2 Cumulative revenue and units — per product
- Aggregate revenue (and units) per product per day, then take the cumulative sum **within each product**, restarting for each item.

```python
by_item = (dated.groupby(["item", "transaction_date"])["total_spent"].sum()
             .reset_index().sort_values(["item", "transaction_date"]))
by_item["cum_revenue"] = by_item.groupby("item")["total_spent"].cumsum()
```

### 6.3 Cumulative percentage of annual total
- `cum_pct = cumulative revenue / full-year revenue`, for the cafe and for each product.
- Used to report the date each milestone (25% / 50% / 75% / 100%) is reached.

### 6.4 Pareto (cumulative revenue share by product)
- Sort products by revenue, **descending**, then take the cumulative sum of revenue share.
- Flag the products that together make up at least 80% of revenue.

```python
pareto = (df.groupby("item")["total_spent"].sum()
            .sort_values(ascending=False).to_frame("revenue"))
pareto["share"] = pareto["revenue"] / pareto["revenue"].sum()
pareto["cum_share"] = pareto["share"].cumsum()
```

### 6.5 Cumulative sum rules
- Aggregate first, then accumulate (never cumsum raw transaction rows, since multiple rows share the same date and row order within a day is arbitrary).
- The final value of every running total must equal the matching full-period total (see acceptance criteria).
- Cumulative sums reset per year if more years of data are added later.
- Milestone percentages (6.3) are measured against **dated** revenue, so the running total reaches exactly 100% on Dec 31.

Equivalent SQL for the daily running total:

```sql
SELECT transaction_date,
       SUM(total_spent) AS daily_revenue,
       SUM(SUM(total_spent)) OVER (ORDER BY transaction_date) AS cum_revenue
FROM cafe_sales_cleaned
WHERE transaction_date IS NOT NULL
GROUP BY transaction_date
ORDER BY transaction_date;
```

## 7. Dimensions and Filters

The analysis must let the owner slice every metric by:
- Product (`item`)
- Time: day, week, month, quarter, day of week
- Payment method (including Unknown)
- Location (In-store / Takeaway / Unknown)

NULL values are displayed as **Unknown** in every breakdown rather than hidden, so the owner can see how much of the data each split actually covers.

## 8. Deliverables

1. **Product summary table:** revenue, units, transactions, ATV, revenue share, and rank for each product.
2. **Monthly trend table and chart:** revenue and units by month, per product and total, with month-over-month growth.
3. **Cumulative revenue chart (cafe):** daily running total line for the year, with milestone markers.
4. **Cumulative revenue chart (per product):** one running-total line per product on the same axes.
5. **Pareto chart:** revenue bars by product (descending) with a cumulative share line and an 80% reference line.
6. **Channel breakdown:** revenue by payment method and by location, overall and per product.
7. **Key findings:** a short written summary of the top 3–5 insights and recommended actions.

## 9. Acceptance Criteria

- Total revenue across all outputs reconciles to `SUM(total_spent)` for the full table ($89,042.00).
- The last value of every cumulative series equals the corresponding full-period total of **dated** revenue; dated + undated revenue equals total revenue.
- `quantity × price_per_unit = total_spent` for every row where all three are known (verified: 0 mismatches).
- Per-product cumulative totals sum to the cafe-level cumulative total on every date.
- The Pareto `cum_share` ends at exactly 100%.
- Every chart has a title, labeled axes, and currency formatting for revenue.
- Any rows excluded or adjusted for data quality are counted and documented.

## 10. Data Quality Notes

Checks on the cleaned table:

| Check | Result |
|---|---|
| Rows | 9,974 |
| Duplicate `transaction_id` | 0 |
| NULLs in `item`, `quantity`, `price_per_unit`, `total_spent` | 0 |
| Rows where `quantity × price ≠ total_spent` | 0 |
| One price per item | Yes |
| Fractional quantities | 0 |

Remaining gaps and how the analysis treats them:

| Field | NULL rows | % of rows | Treatment |
|---|---|---|---|
| `transaction_date` | 460 | 4.6% | Kept in product totals; excluded from time trends and cumulative sums; reported as "Undated" ($4,173.50, 4.7% of revenue). |
| `payment_method` | 3,168 | 31.8% | Shown as "Unknown"; payment-method findings cover about two-thirds of transactions. |
| `location` | 3,952 | 39.6% | Shown as "Unknown"; location findings cover about 60% of transactions. |

Keeping these as NULL matters for the channel analysis. Filling missing payment method with "Cash" and location with "In-store" would make both look dominant. With NULLs kept, the known values are close to even (Cash 2,254 / Credit Card 2,268 / Digital Wallet 2,284; In-store 3,006 / Takeaway 3,016).

## 11. Assumptions

- Each row is a completed sale; there are no refunds or voids in the data.
- Prices are in a single currency and did not change during 2023.
- Weeks start on Monday.
- **Missing items with an ambiguous price are assigned to the more common item at that price:** $3 → Cake (not Juice), $4 → Smoothie (not Sandwich). Cake sells more than Juice, and Smoothie more than Sandwich, so these are the most likely matches. The trade-off is that a few real Juice or Sandwich sales may be counted as Cake or Smoothie. The cleaned file doesn't record which rows were filled this way; to measure the impact, run `SELECT price_per_unit, COUNT(*) FROM temp_cafe_sales WHERE item IS NULL AND price_per_unit IN (3, 4) GROUP BY 1;` between Steps 7 and 8.

## 12. Out of Scope

- Cost of goods, profit, and margin (no cost data available).
- Customer-level analysis such as repeat visits (no customer ID).
- Hourly or time-of-day analysis (no timestamp).
- Forecasting future sales.
