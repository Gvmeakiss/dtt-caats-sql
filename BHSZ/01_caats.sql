-- ============================================================
-- 通用佣金重算 CAATS 模板（证券经纪场景）
-- ------------------------------------------------------------
-- 演示技法：资金流水 × 约定佣金率 重算佣金，与账面佣金比对差异
-- 说明：合成 T_ 表与字段，不含任何客户、账户、机构等真实信息。
-- ============================================================

-- 合成表结构（示意）：
--   T_FUND_FLOW        (flow_id, fund_account, turnover, commission,
--                       summary_code, money_type, org_id)
--   T_COMMISSION_RATE  (fund_id, money_type, org_id, award_rate)

-- 1. 资金流水关联佣金率表
SELECT a.*, b.fund_id, b.money_type, b.org_id, b.award_rate
INTO   dbo.CAATS_FUND_RATE
FROM   dbo.T_FUND_FLOW a
LEFT JOIN dbo.T_COMMISSION_RATE b
       ON a.fund_account = b.fund_id;

-- 2. 重算佣金
ALTER TABLE dbo.CAATS_FUND_RATE ADD recomputed_commission MONEY;
ALTER TABLE dbo.CAATS_FUND_RATE ADD commission_diff       MONEY;

UPDATE dbo.CAATS_FUND_RATE
SET    recomputed_commission = turnover * award_rate;

-- 仅对交易类摘要重算
UPDATE dbo.CAATS_FUND_RATE
SET    recomputed_commission = 0
WHERE  summary_code NOT IN (221001,220000,220003,220095,
                            220024,220188,220094,220100,221101);

UPDATE dbo.CAATS_FUND_RATE
SET    commission_diff = commission - recomputed_commission;

-- 3. 差异抽样与复核
SELECT * FROM dbo.CAATS_FUND_RATE
WHERE  commission = 0 AND turnover <> 0;

SELECT DISTINCT award_rate FROM dbo.CAATS_FUND_RATE;

SELECT * FROM dbo.CAATS_FUND_RATE
WHERE  award_rate IS NULL;
