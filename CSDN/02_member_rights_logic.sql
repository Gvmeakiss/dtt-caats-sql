-- ============================================================
-- 通用会员权责（递延收益）确认 CAATS 模板（Hive SQL）
-- ------------------------------------------------------------
-- 演示技法：根据会员起止时间按天摊销权责金额，区分会员类型与主体
-- 说明：合成 dwd_ 表与字段，不含任何客户、主体、商品等真实信息。
-- ============================================================

-- 合成表结构（示意）：
--   dwd_vip_user_record (order_no, member_type, start_time, end_time)
--   dwd_order_detail    (order_no, real_price, use_balance_price,
--                        use_ios_balance_price, redeem_price, member_type,
--                        order_status)
--   dwd_order_pay       (order_no, pay_type, pay_value)

-- 1) 计算会员有效起止与天数
WITH vip_base AS (
  SELECT
    order_no,
    member_type,
    from_unixtime(start_time) AS start_time,
    from_unixtime(end_time)   AS end_time,
    DATEDIFF(from_unixtime(end_time), from_unixtime(start_time), 'dd') + 1 AS days
  FROM dwd_vip_user_record
  WHERE order_no IS NOT NULL
),
-- 2) 关联订单实付与支付构成
order_amt AS (
  SELECT
    o.order_no,
    o.real_price,
    o.use_balance_price,
    o.use_ios_balance_price,
    o.redeem_price,
    o.member_type
  FROM dwd_order_detail o
  WHERE order_status IN (3,4,5)
)
-- 3) 按天摊销权责（金额 / 天数）
SELECT
  v.member_type,
  v.company_code,
  SUM((o.real_price + o.use_balance_price + o.use_ios_balance_price + o.redeem_price)
      / v.days) AS daily_amount
FROM vip_base v
JOIN order_amt o ON v.order_no = o.order_no
WHERE '${tdate}' BETWEEN SUBSTR(v.start_time,1,10) AND SUBSTR(v.end_time,1,10)
GROUP BY v.member_type, v.company_code;
