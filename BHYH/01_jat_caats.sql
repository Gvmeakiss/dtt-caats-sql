-- ============================================================
-- 通用应付利息预提（JAT）CAATS 模板
-- ------------------------------------------------------------
-- 演示技法：按利率与计息余额重算应计利息，与账面预提比对
-- 说明：合成 T_ 表与字段，不含任何客户、账户等真实信息。
-- ============================================================

-- 合成表结构（示意）：
--   T_INTEREST_ACCRUAL (acct_id, ccy, balance, rate, days, int_amt, memo)

-- 1. 规模与维度核对
SELECT COUNT(*) FROM dbo.T_INTEREST_ACCRUAL;
SELECT SUM(CAST(int_amt AS FLOAT)) AS total_accrued FROM dbo.T_INTEREST_ACCRUAL;
SELECT DISTINCT ccy  FROM dbo.T_INTEREST_ACCRUAL;
SELECT DISTINCT memo FROM dbo.T_INTEREST_ACCRUAL;

-- 2. 重算：计息余额 × 日利率 × 计息天数
SELECT
  acct_id,
  ccy,
  balance,
  rate,
  days,
  balance * rate * days                 AS recomputed_int,
  CAST(int_amt AS FLOAT)               AS booked_int,
  balance * rate * days - CAST(int_amt AS FLOAT) AS diff
FROM dbo.T_INTEREST_ACCRUAL
WHERE CAST(int_amt AS FLOAT) <> balance * rate * days;
