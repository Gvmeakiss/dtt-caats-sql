# dtt-caats-sql · 通用 CAATS / 勾稽 SQL 模板

一套**通用计算机辅助审计分析（CAATS）SQL 模板**，覆盖销售勾稽、物料追索、佣金重算、利息预提、支付对账与会员权责递延等典型审计场景。<sub>*A reusable library of Computer-Assisted Audit Techniques (CAATS) in SQL — covering sales reconciliation, BOM tracing, commission recomputation, interest accrual, payment reconciliation and deferred membership revenue.*</sub>

## 📋 合规与脱敏声明 / Compliance

- 本仓库仅包含**通用工具代码 / 方法论演示**，不含任何客户名称、法律实体、内部标识、真实地址、财务数据或客户工作底稿（xlsx / sql / zip 等）。
- 所有示例数据均为**合成数据**（`C001..C00N` 公司代码、`T_` / `dwd_` 表、模拟数据集），依据《个人信息保护法》《数据安全法》《反不正当竞争法》脱敏。
- 与任何前雇主、客户无关（*Not affiliated with or endorsed by any employer or client.*）。

## 🎯 功能模块 / Modules

| 模板文件 | 审计技法 / Technique |
| --- | --- |
| `BHSZ/01_caats.sql` | **证券经纪佣金重算**：以资金流水 `turnover` × 约定佣金率 `award_rate` 重算佣金，与账面 `commission` 比对差异；仅对交易类摘要（`summary_code`）重算，并对零佣金有流水、佣金率为空等异常做抽样复核。 |
| `BHYH/01_jat_caats.sql` | **应付利息预提（JAT）重算**：以计息余额 × 日利率 × 计息天数 重算应计利息，与账面 `int_amt` 比对差异；含币种、维度与规模核对。 |
| `CSDN/01_member_recon.sql` | **多支付渠道流水合并与对账**：将多渠道（A / B / C）支付流水 `UNION ALL` 合并为统一视图，统计流水/订单/用户规模与渠道分布，并与订单表金额勾稽。 |
| `CSDN/02_member_rights_logic.sql` | **会员权责（递延收益）确认**：根据会员起止时间按天摊销权责金额，区分会员类型与主体（`company_code`）；按当前账期 `${tdate}` 过滤并汇总每日权责（Hive SQL）。 |
| `HM/01_sales_order_match.sql` | **销售订单 ↔ 收入勾稽**：按交货单号勾稽订单与收入明细；外币按期间汇率折算本位币、退货冲红、关联方剔除；关键字段数据质量、金额分层、大额/高频客户、收货地址集中度、运输天数异常（签收早于发货）识别。 |
| `HM/02_material_trace.sql` | **产品物料追索（BOM）**：生产订单产出量 ↔ BOM 组件消耗量勾稽；关键字段空值/重复检测；按类别、按月份统计产出与消耗。 |
| `JSM/01_data_analysis.sql` | **销售出库单审计**：交付单 ↔ 退货单勾稽；刷单检测、分销商识别、内部交易剔除；客户/渠道/地址集中度分析、非分销商囤货行为识别、GMV 与平台账单勾稽。 |

## 🚀 快速开始 / Quick Start

仓库中的 SQL 为**通用模板**，表名（`T_` / `dwd_`）与字段均为合成约定，请替换为你自己的脱敏抽取结果后再执行。

- 多数模板为 **SQL Server / T-SQL** 风格（`dbo.` 前缀、`ALTER TABLE … ADD` 中间表落表、`INTO` 建表）；
- `CSDN/02_member_rights_logic.sql` 为 **Hive SQL** 风格（CTE、`from_unixtime`、`DATEDIFF(...,'dd')`、`${tdate}` 参数化）。

最小用法示例（销售订单↔收入勾稽）：

```sql
-- 1) 标记内部关联交易（关联方剔除）
ALTER TABLE dbo.T_SALES_ORDER ADD is_internal CHAR(1);
UPDATE dbo.T_SALES_ORDER SET is_internal = 'N';
UPDATE dbo.T_SALES_ORDER
SET    is_internal = 'Y'
WHERE  delivery_no IN (
    SELECT DISTINCT delivery_no
    FROM dbo.T_REVENUE_DETAIL WHERE is_internal = 'Y');

-- 2) 外币折算本位币、退货冲红
ALTER TABLE dbo.T_SALES_ORDER ADD net_base_signed FLOAT;
UPDATE dbo.T_SALES_ORDER
SET    net_base_signed = -((net_amount_orig - tax) * fx_to_base)
WHERE  order_type IN ('RETURN_ORDER_3C','CONSIGNMENT_REVERSE','SALES_RETURN');
UPDATE dbo.T_SALES_ORDER
SET    net_base_signed =  ((net_amount_orig - tax) * fx_to_base)
WHERE  order_type NOT IN ('RETURN_ORDER_3C','CONSIGNMENT_REVERSE','SALES_RETURN');
```

## 📥 数据口径 / Data Contract

模板统一使用以下合成命名约定，便于映射到自有 schema：

- **表前缀**：`T_`（事务/明细类合成表）、`dwd_`（数仓明细层合成表）。
- **公司/主体代码**：`C001..C00N`，不含真实法律实体。
- **通用字段约定**：
  - 金额类：`*_amount` / `net_amount_orig` / `tax` / `real_price`，外币原币与本位币区分。
  - 汇率：`fx_to_base`（原币 → 本位币期间汇率）。
  - 币种：`ccy` / `currency`。
  - 时间：`order_date` / `ship_date` / `sign_date` / `start_time` / `end_time`（Unix 时间戳，Hive 中经 `from_unixtime` 转换）。
  - 状态/标识：`doc_status`、`order_status`、`is_internal`、`is_return`、`is_brush`、`is_distributor`、`summary_code`、`dc_flag`（借贷标识）等审计筛选标记。
  - 勾稽键：`delivery_no`、`order_no`、`doc_no`、`material`、`fund_account`、`acct_id`、`user_id` 等连接维度。
- 中间结果表（如 `dbo.CAATS_FUND_RATE`、`dbo.T_PAY_ALL`）为模板**落表产物**，可按引擎替换为临时表/CTE。

> 提示：将上方合成表替换为你的脱敏抽取结果，并保持字段命名一致即可直接复用逻辑。

## 🔍 核心审计技法 / Core Techniques

- **多源勾稽（Multi-source reconciliation）**：订单 ↔ 收入、交付 ↔ 退货、产出 ↔ 组件消耗、GMV ↔ 平台账单等量价双维核对。
- **外币折算（FX translation）**：按期间汇率 `fx_to_base` 将原币金额折算本位币后勾稽。
- **冲红 / 退货处理（Reversal / red-letter handling）**：以负向金额标记退货与反向类型，保证净额口径正确。
- **重计算（Recomputation）**：佣金（流水 × 费率）、利息（余额 × 利率 × 天数）等按独立逻辑重算并与账面比对差异。
- **数据质量检查（Data-quality checks）**：关键字段空值率、重复值检测等通用模式。
- **集中度分析（Concentration analysis）**：大额/高频客户、渠道、收货地址集中度识别。
- **业务真实性检测（Business-authenticity detection）**：刷单识别、内部交易剔除、分销商/非分销商囤货、运输天数异常（签收早于发货）等。

## 📚 参考 / References

- CAATS（Computer-Assisted Audit Techniques）方法论，参考审计准则中关于分析程序与重计算程序的通用框架。
- 各模板顶部注释已标注所演示技法与合成表结构，可直接阅读源码。

<sub>个人项目，与任何前雇主/客户无关。</sub>
