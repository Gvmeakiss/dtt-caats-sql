-- ============================================================
-- 通用销售出库单审计 CAATS 模板
-- ------------------------------------------------------------
-- 演示技法：
--   1) 交付单 ↔ 退货单勾稽
--   2) 刷单检测、分销商识别、内部交易剔除
--   3) 关键字段数据质量检查
--   4) 金额 / 客户 / 渠道 / 地址集中度分析
--   5) 非分销商囤货行为、GMV 与平台账单勾稽
-- 说明：合成 T_ 表与字段，不含任何客户、平台、地址等真实信息。
-- ============================================================

-- 合成表结构（示意）：
--   T_DELIVERY   (doc_no, order_no, doc_date, customer, address,
--                channel, qty, tax_incl_amount, doc_status, is_gift)
--   T_RETURN     (order_no, return_date, return_type)
--   T_BRUSH_ORDER(doc_no)
--   T_DISTRIBUTOR(short_name)
--   T_INTERNAL_LIST(internal_code)
--   T_PLATFORM_BILL(order_no, fee_item, settled_amount)

-- 1. 标记内部交易 / 退货 / 刷单 / 分销商
ALTER TABLE dbo.T_DELIVERY ADD is_internal    CHAR(1);
ALTER TABLE dbo.T_DELIVERY ADD is_return      CHAR(1);
ALTER TABLE dbo.T_DELIVERY ADD is_brush       CHAR(1);
ALTER TABLE dbo.T_DELIVERY ADD is_distributor CHAR(1);

UPDATE dbo.T_DELIVERY SET is_internal = 'N';
UPDATE dbo.T_DELIVERY SET is_internal = 'Y'
WHERE customer IN (SELECT internal_code FROM dbo.T_INTERNAL_LIST);

UPDATE dbo.T_DELIVERY SET is_return = 'N';
UPDATE dbo.T_DELIVERY SET is_return = 'Y'
WHERE order_no IN (SELECT DISTINCT order_no FROM dbo.T_RETURN);

UPDATE dbo.T_DELIVERY SET is_brush = 'N';
UPDATE dbo.T_DELIVERY SET is_brush = 'Y'
WHERE doc_no IN (SELECT DISTINCT doc_no FROM dbo.T_BRUSH_ORDER);

UPDATE dbo.T_DELIVERY SET is_distributor = 'N';
UPDATE dbo.T_DELIVERY SET is_distributor = 'Y'
WHERE customer IN (SELECT DISTINCT short_name FROM dbo.T_DISTRIBUTOR);

-- 2. 审计口径汇总（剔除内部 / 刷单，仅已审核）
SELECT COUNT(DISTINCT doc_no) AS order_cnt,
       SUM(qty)               AS qty,
       SUM(tax_incl_amount)   AS amount
FROM dbo.T_DELIVERY
WHERE doc_date BETWEEN '2021-01-01' AND '2024-03-31'
  AND is_internal = 'N' AND is_return = 'N'
  AND is_brush = 'N' AND doc_status = 'AUDITED';

-- 3. 月度趋势
SELECT YEAR(doc_date) AS yr, MONTH(doc_date) AS mth,
       COUNT(DISTINCT doc_no) AS order_cnt,
       SUM(tax_incl_amount)   AS amount
FROM dbo.T_DELIVERY
WHERE is_internal='N' AND is_return='N' AND is_brush='N' AND doc_status='AUDITED'
GROUP BY YEAR(doc_date), MONTH(doc_date)
ORDER BY yr, mth;

-- 4. 重点客户 / 渠道集中度
SELECT customer, COUNT(DISTINCT doc_no) AS order_cnt, SUM(tax_incl_amount) AS amount
FROM dbo.T_DELIVERY
WHERE is_internal='N' AND is_return='N' AND is_brush='N' AND doc_status='AUDITED'
GROUP BY customer ORDER BY amount DESC;

SELECT channel, COUNT(DISTINCT doc_no) AS order_cnt, SUM(tax_incl_amount) AS amount
FROM dbo.T_DELIVERY
WHERE is_internal='N' AND is_return='N' AND is_brush='N' AND doc_status='AUDITED'
GROUP BY channel ORDER BY amount DESC;

-- 5. 非分销商囤货行为
SELECT customer, address,
       COUNT(DISTINCT doc_no) AS order_cnt,
       SUM(tax_incl_amount)    AS amount
FROM dbo.T_DELIVERY
WHERE is_internal='N' AND is_return='N' AND is_brush='N'
  AND doc_status='AUDITED' AND is_distributor='N'
GROUP BY customer, address ORDER BY amount DESC;

-- 6. GMV 与平台账单勾稽
SELECT a.order_no, a.tax_incl_amount, b.fee_item, b.settled_amount
FROM dbo.T_DELIVERY a
INNER JOIN dbo.T_PLATFORM_BILL b ON a.order_no = b.order_no
WHERE a.is_internal='N' AND a.is_return='N' AND a.is_brush='N'
  AND a.doc_status='AUDITED' AND a.is_gift='N' AND b.fee_item='GOODS';
