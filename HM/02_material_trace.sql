-- ============================================================
-- 通用产品物料追索（BOM）CAATS 模板
-- ------------------------------------------------------------
-- 演示技法：
--   1) 生产订单产出量 ↔ BOM 组件消耗量勾稽
--   2) 关键字段数据质量与重复值检测
--   3) 按类别 / 月度统计产出与消耗
-- 说明：合成 T_ 表与字段，不含任何客户、产品、工厂等真实信息。
-- ============================================================

-- 合成表结构（示意）：
--   T_PROD_ORDER   (order_id, material, category, delivered_qty,
--                   start_date, complete_date, status)
--   T_BOM          (category, finished_material, component_material,
--                   spec, finished_desc, component_desc)
--   T_COMPONENT_ISSUE (order_id, material, issue_qty, dc_flag,
--                   move_type, posting_date, batch)

-- 1. 数据质量：关键字段空值检查（模式复用）
SELECT 'material' AS col, COUNT(*) AS null_cnt
FROM dbo.T_PROD_ORDER WHERE material IS NULL OR material = '';
-- 对 order_id / category / delivered_qty / complete_date 同样检查。

-- 2. 重复值检测（生产订单）
SELECT *
FROM dbo.T_PROD_ORDER a
WHERE EXISTS (
  SELECT 1 FROM dbo.T_PROD_ORDER b
  WHERE b.order_id = a.order_id AND b.material = a.material
  GROUP BY b.order_id, b.material HAVING COUNT(1) > 1);

-- 3. 按类别统计产出总数量
SELECT a.category, SUM(b.delivered_qty) AS total_output
FROM dbo.T_BOM a
LEFT JOIN dbo.T_PROD_ORDER b ON a.finished_material = b.material
GROUP BY a.category
ORDER BY a.category;

-- 4. 按类别 / 借贷标识统计组件消耗数量
SELECT a.category, b.dc_flag, SUM(b.issue_qty) AS total_issue
FROM dbo.T_BOM a
LEFT JOIN dbo.T_COMPONENT_ISSUE b ON a.component_material = b.material
GROUP BY a.category, b.dc_flag
ORDER BY a.category, b.dc_flag;

-- 5. 按月统计产品产出总量
SELECT a.category, a.finished_material, a.finished_desc,
       YEAR(b.complete_date)  AS yr,
       MONTH(b.complete_date) AS mth,
       SUM(b.delivered_qty)   AS output
FROM dbo.T_BOM a
LEFT JOIN dbo.T_PROD_ORDER b ON a.finished_material = b.material
GROUP BY a.category, a.finished_material, a.finished_desc,
         YEAR(b.complete_date), MONTH(b.complete_date)
ORDER BY a.category, yr, mth;

-- 6. 按月统计物料取用数量
SELECT a.category, a.component_material, a.spec, a.component_desc,
       YEAR(b.posting_date)  AS yr,
       MONTH(b.posting_date) AS mth,
       b.dc_flag,
       SUM(b.issue_qty) AS issue_total
FROM dbo.T_BOM a
LEFT JOIN dbo.T_COMPONENT_ISSUE b ON a.component_material = b.material
GROUP BY a.category, a.component_material, a.spec, a.component_desc,
         YEAR(b.posting_date), MONTH(b.posting_date), b.dc_flag
ORDER BY a.category, yr, mth;
