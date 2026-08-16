-- ============================================================
-- 通用支付流水合并与对账 CAATS 模板
-- ------------------------------------------------------------
-- 演示技法：多支付渠道（第三方支付 / 钱包 / 电商）流水合并、
--           订单 / 用户规模统计、与订单表金额勾稽
-- 说明：合成 T_ 表与字段，不含任何客户、平台、账户等真实信息。
-- ============================================================

-- 合成表结构（示意）：
--   T_PAY_CHANNEL_A (order_no, user_id, pay_amount, pay_status, pay_time)
--   T_PAY_CHANNEL_B (order_no, user_id, pay_amount, pay_status, pay_time)
--   T_PAY_CHANNEL_C (order_no, user_id, pay_amount, pay_status, pay_time)
--   T_ORDER      (order_no, order_amount, order_status)

-- 1. 多渠道流水合并为统一视图
SELECT * INTO dbo.T_PAY_ALL FROM (
  SELECT 'PAY_CHANNEL_A' AS channel, * FROM dbo.T_PAY_CHANNEL_A
  UNION ALL
  SELECT 'PAY_CHANNEL_B' AS channel, * FROM dbo.T_PAY_CHANNEL_B
  UNION ALL
  SELECT 'PAY_CHANNEL_C' AS channel, * FROM dbo.T_PAY_CHANNEL_C
) a;

-- 2. 规模核对
SELECT COUNT(*)                       AS pay_rows   FROM dbo.T_PAY_ALL;
SELECT COUNT(DISTINCT order_no)       AS order_cnt  FROM dbo.T_PAY_ALL;
SELECT COUNT(DISTINCT user_id)        AS user_cnt   FROM dbo.T_PAY_ALL;
SELECT channel, COUNT(*) AS rows FROM dbo.T_PAY_ALL GROUP BY channel;

-- 3. 与订单表金额勾稽
SELECT a.order_no, a.pay_amount, b.order_amount
FROM dbo.T_PAY_ALL a
LEFT JOIN dbo.T_ORDER b ON a.order_no = b.order_no
WHERE a.pay_amount <> b.order_amount;
