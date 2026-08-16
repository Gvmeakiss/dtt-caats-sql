-- ============================================================
-- 通用销售订单 ↔ 收入勾稽 CAATS 模板
-- ------------------------------------------------------------
-- 演示技法：
--   1) 订单表与收入明细表按交货单号勾稽
--   2) 外币按期间汇率折算本位币、退货冲红、关联方剔除
--   3) 关键字段数据质量（空值/重复）检查
--   4) 订单金额分层、大额/高频客户、收货地址集中度分析
--   5) 运输天数异常（签收早于发货）识别
-- 说明：全部使用合成 T_ 表与字段，不含任何客户/平台/地址等真实信息。
--       非任何前雇主资产，仅用于演示审计分析技法。
-- ============================================================

-- 合成表结构（示意，实际数据请替换为脱敏后的抽取结果）：
--   T_SALES_ORDER (
--     order_id, delivery_no, sold_to, ship_to, sku, qty,
--     net_amount_orig, tax, currency, fx_to_base,
--     order_date, ship_date, sign_date, order_type, address, country)
--   T_REVENUE_DETAIL (
--     delivery_no, revenue_amount, currency, period,
--     revenue_account, is_internal)

-- 1. 数据规模与完整性核对
SELECT COUNT(*)                       AS order_rows   FROM dbo.T_SALES_ORDER;
SELECT COUNT(DISTINCT delivery_no)    AS delivery_cnt FROM dbo.T_REVENUE_DETAIL;

-- 2. 标记内部关联交易
ALTER TABLE dbo.T_SALES_ORDER ADD is_internal CHAR(1);
UPDATE dbo.T_SALES_ORDER SET is_internal = 'N';
UPDATE dbo.T_SALES_ORDER
SET    is_internal = 'Y'
WHERE  delivery_no IN (SELECT DISTINCT delivery_no
                       FROM dbo.T_REVENUE_DETAIL WHERE is_internal = 'Y');

-- 3. 不含税本位币收入 = (订单实付 - 税) * 汇率
ALTER TABLE dbo.T_SALES_ORDER ADD net_base FLOAT;
UPDATE dbo.T_SALES_ORDER
SET    net_base = (net_amount_orig - tax) * fx_to_base;

-- 4. 退货订单冲红（负向）
ALTER TABLE dbo.T_SALES_ORDER ADD net_base_signed FLOAT;
UPDATE dbo.T_SALES_ORDER
SET    net_base_signed = -net_base
WHERE  order_type IN ('RETURN_ORDER_3C','CONSIGNMENT_REVERSE','SALES_RETURN');
UPDATE dbo.T_SALES_ORDER
SET    net_base_signed =  net_base
WHERE  order_type NOT IN ('RETURN_ORDER_3C','CONSIGNMENT_REVERSE','SALES_RETURN');

-- 5. 数据质量：关键字段空值率（每个字段复用此模板）
SELECT 'sold_to' AS col, COUNT(*) AS null_cnt
FROM dbo.T_SALES_ORDER WHERE sold_to IS NULL OR sold_to = '';
-- 对 order_id / order_type / sku / order_date / ship_date /
--    sign_date / address / country 同样检查。

-- 6. 订单金额分层分析
SELECT
  CASE
    WHEN net_base_signed >= 0   AND net_base_signed <= 500    THEN '[0-500]'
    WHEN net_base_signed > 500  AND net_base_signed <= 3000   THEN '[500-3000]'
    WHEN net_base_signed > 3000 AND net_base_signed <= 10000  THEN '[3000-1万]'
    WHEN net_base_signed > 10000                            THEN '[>1万]'
    WHEN net_base_signed < 0                               THEN '[<0]'
    ELSE 'notset' END AS bucket,
  COUNT(DISTINCT order_id) AS order_cnt,
  SUM(net_base_signed)     AS revenue
FROM dbo.T_SALES_ORDER
WHERE is_internal = 'N'
GROUP BY
  CASE
    WHEN net_base_signed >= 0   AND net_base_signed <= 500    THEN '[0-500]'
    WHEN net_base_signed > 500  AND net_base_signed <= 3000   THEN '[500-3000]'
    WHEN net_base_signed > 3000 AND net_base_signed <= 10000  THEN '[3000-1万]'
    WHEN net_base_signed > 10000                            THEN '[>1万]'
    WHEN net_base_signed < 0                               THEN '[<0]'
    ELSE 'notset' END
ORDER BY bucket;

-- 7. 大额 / 高频下单客户统计（脱敏后的客户编码）
SELECT sold_to, COUNT(DISTINCT order_id) AS order_cnt, SUM(net_base_signed) AS revenue
FROM dbo.T_SALES_ORDER
WHERE is_internal = 'N'
GROUP BY sold_to
ORDER BY revenue DESC;

-- 8. 收货地址集中度（识别同一地址多订单 / 多客户）
SELECT address,
       COUNT(DISTINCT sold_to)  AS buyer_cnt,
       COUNT(DISTINCT order_id)  AS order_cnt
FROM dbo.T_SALES_ORDER
WHERE is_internal = 'N'
GROUP BY address
ORDER BY SUM(net_base_signed) DESC;

-- 9. 运输天数异常：签收早于发货
ALTER TABLE dbo.T_SALES_ORDER ADD transport_days INT;
UPDATE dbo.T_SALES_ORDER
SET    transport_days = DATEDIFF(dd, ship_date, sign_date);
SELECT order_id, ship_date, sign_date, transport_days
FROM dbo.T_SALES_ORDER
WHERE is_internal = 'N' AND transport_days < 0
ORDER BY transport_days;
