# Criterion-centric Batching for Review/Revise — Design Spec

- **Date**: 2026-05-24
- **Skills**: `prd-analysis`, `system-design`
- **Author**: 协同设计（用户 + Claude）
- **Status**: Approved (design phase) → ready for implementation plan

---

## 1. Motivation

当前的 review/revise 流是 **file-centric**（按 leaf 分组）：

- Review 端 cross-reviewer 按 artifact class（features/journeys/architecture）切 cluster，
  每个 cluster 10–15 文件 × 全部 LLM-type criteria。
- Revise 端 reviser 按 `file:` 字段把 issue 分组，每个 leaf 一个 reviser，handle 该 leaf 的全部 issue。

观察到的低效点：
1. **LLM 注意力被稀释**：一个 reviser 拿到的 issue 列表往往横跨多种类型（如同时有
   traceability、accessibility、state-machine 三类），LLM 在不同类型间来回切换，
   每类都要重新建立 fix-pattern 的认知。
2. **fix-pattern 无法跨 leaf 复用**：N 个 leaf 上的同一个 CR-PP06 issue 现在被 N 个 reviser
   独立处理，每个 reviser 都要重新推理"如何修这一类问题"。
3. **Review 端同理**：一个 reviewer 一次性应用 50+ 个 CR-ID 到 10 个文件上，必然存在
   注意力切换成本。

Claude Code 在 prompt-cache 加同类批处理上的最佳实践是：**把同类工作聚到一个 turn 内做完**，
避免重复推理同一类问题。

## 2. Design Overview

把 grouping 维度从 **file** 切换到 **criterion category**：

| 阶段 | 当前 | 新方案 |
|------|------|--------|
| Review (cross-reviewer cluster) | 按 artifact class 切，每 cluster 跑全部 criteria | 按 **category** 切，每 cluster 跑同一 category 的所有 CR-ID（across all leaves） |
| Revise (reviser grouping) | 按 `file:` 分组，每 leaf 一个 reviser | 按 **criterion_id** 分组，每 cluster 一个 reviser 跨多 leaf 处理同类 issue（Edit cap=8） |
| Reviser 写入工具 | `Read → 内存合并 → Write` 全文 | **Edit-only**：每 issue 1 次精确替换（unique `old_string`） |
| Adversarial reviewer | 不变（critical 触发，量小） | 不变 |

并发写入冲突解决：靠 `Edit` 的 unique-match 语义。同一 leaf 被多个 reviser 改不同位置时，
各自的 `old_string` 是不同片段，不冲突；冲突时（罕见的同位置修改）`Edit` 报错被
self-loop 捕获，由形式校验脚本兜底。

## 3. Revise 端详细设计（P3）

### 3.1 grouping 算法

替换 `revise/index.md` Step 2 的"按 file 分组"逻辑：

```python
# 伪代码 — 实际放在 revise/index.md 的 prose 描述 + 一个新 script
issues = read_all(<artifact-root>/.review/round-<N>/issues/*.md)
state_new = [i for i in issues if i.state == "new"]
by_criterion = group_by(state_new, key=lambda i: i.criterion_id)

clusters = []
for criterion_id, issue_list in by_criterion.items():
    for chunk in chunks_of(issue_list, size=EDIT_CAP):   # default 8
        clusters.append({
            "cluster_id": f"R{round}-CC-{counter}",      # criterion-cluster
            "criterion_id": criterion_id,
            "category": lookup_category(criterion_id),    # 见 §5
            "issues": [i.id for i in chunk],
            "affected_leaves": sorted(unique(i.file for i in chunk)),
        })
```

state.yml 中新增 `revise_clusters:` 段（替代 `revise_groups:`）：

```yaml
revise_clusters:
  - cluster_id: R3-CC-001
    criterion_id: CR-PP06
    category: traceability
    issues: [I-007, I-019, I-024]
    affected_leaves: [features/F-001-checkout.md, features/F-003-cart.md, journeys/J-002.md]
  - cluster_id: R3-CC-002
    criterion_id: CR-PP24
    category: coherence
    issues: [I-012, I-031]
    affected_leaves: [features/F-001-checkout.md, features/F-005-orders.md]
```

注意 F-001-checkout.md 出现在两个 cluster 里——这是预期的（被两个 reviser 改不同 issue）。

### 3.2 Reviser sub-agent 契约变更

`revise/per-issue-reviser-subagent.md` 重写：

- **scope**：一个 reviser 持有 **一个 criterion_id 的 1–8 个 issue**，跨任意多个 leaf。
- **写入工具**：**只能用 `Edit`**。每个 issue 对应一次 Edit；`old_string` 必须 unique；
  禁止 `Write`（除非 reviser 创建新文件——目前 revise 流不允许）。
- **per-leaf 处理顺序**：reviser 内部按 `affected_leaves` 排序依次处理；每个 leaf 内的同 criterion issue 也按 issue_id 排序。
- **read 顺序**：先 Read 该 leaf，然后 Edit 该 leaf，下一个 leaf 重复。**禁止跨 leaf 提前读全部文件**——节省 sub-agent 内部 cache。
- **issue 状态更新**：与原契约一致（new → fixed / false-positive / deferred / superseded）。
- **history append**：同上，不变。

### 3.3 Self-loop（Step 4）形式校验

run-checkers.sh 失败时的处理与原模型有微差：

- **重发触发条件**：与原模型相同（formal-checker 输出 JSON 中报错的 leaf 触发重发）
- **重发 reviser 的 scope**：按**失败的 leaf** 重新组织（不再按 criterion 切分；形式问题往往
  多种类型纠缠，单 criterion 反而难修），其 scope = 该 leaf 上所有 (criterion, issue) 对未完成修复者
- **重发 reviser 的写入工具**：仍然是 **Edit-only**（保持与正常 cluster 一致的契约），
  禁止 Write 全文重写；如果某些形式错误只能通过整体重写解决，reviser 必须发出 FAIL ACK 升级到 HITL，
  而不是绕过 Edit-only 契约
- **3 次失败升级**：与原 SKILL.md 既有逻辑一致（HITL / `--auto` 下 auto_decision.verdict =
  `formal_self_loop_exhausted`）

### 3.4 并发安全证明

并发写入风险分析：

| 场景 | 是否冲突 | 处置 |
|------|---------|------|
| 两个 reviser 改同一 leaf 的不同段落 | 否 | `old_string` 唯一，Edit 串行无冲突 |
| 两个 reviser 改同一 leaf 的同一段落（罕见，跨 criterion 也覆盖同一段落） | 是 | 第二个 Edit 报错（`old_string` 已被改动后不匹配）→ self-loop 捕获 → 重发 |
| 两个 reviser 同时 Edit 同一 issue 的不同字段 | 不可能 | grouping 算法保证 1 issue ∈ 1 cluster |

`Edit` 的失败语义是天然的乐观锁。

### 3.5 fan-out 并发参数

`common/parallel-dispatch.md` Rule 3 修订：

| 角色 | 当前规则 | 新规则 |
|------|---------|--------|
| Reviser (fix subagent) | ≤3 files/cluster | ≤8 issue/cluster (Edit-count cap)；leaf 数不再 cap |
| Writer | ≤20 leaves/batch | 不变 |
| Reviewer | 10–15 files/cluster | 见 §4 |

Rule 5（per-leaf isolation）需要相应弱化：reviser 不再绑定单 leaf，但仍受 criterion 锁定（一个 reviser 只处理 1 个 criterion）。新增"per-criterion isolation"原则：
- 一个 reviser 只能 Edit 它 cluster 里 `affected_leaves` 列出的文件
- 不能 Grep/Glob，所有 leaf 路径预先注入 prompt
- 不能修改 `~/.claude/skills/` 下文件（Rule 7a 不变）

## 4. Review 端详细设计（R1）

### 4.1 cross-reviewer cluster 模型变更

`review/index.md` Step 2 重写 cluster 切分逻辑。

**当前**（按 artifact class）：
```yaml
review_clusters:
  - cluster_id: R3-V-features-001
    files: [features/F-001.md, ..., features/F-010.md]
    criteria: <all LLM-type CR-IDs>
  - cluster_id: R3-V-journeys-001
    files: [journeys/J-001.md, journeys/J-002.md]
    criteria: <all LLM-type CR-IDs>
```

**新**（按 category）：
```yaml
review_clusters:
  - cluster_id: R3-V-traceability
    category: traceability
    files: <all leaves>
    criteria: [CR-PP06]
  - cluster_id: R3-V-evidence
    category: evidence
    files: <all leaves>
    criteria: [CR-PP07, CR-PP08, CR-PP09]
  ...（每个 category 一个 cluster）
```

每个 reviewer 都看全 bundle，但只跑一个 category 的 CR-ID。

### 4.2 cluster 上限保护

若一个 category 内的 CR-ID × leaves 数过大导致 input 超阈，按 leaf-block 切分（如 25 leaves/sub-cluster），并把同一 category 切成多个 sub-cluster 并行（共享 criteria，分配不同 leaf 子集）。阈值放在 `common/config.yml`：

```yaml
review:
  cluster_leaf_cap: 25     # 一个 reviewer 最多看几个 leaf
  cluster_category_cap: 1  # 一个 reviewer 只跑一个 category（不可调）
```

### 4.3 compute-review-scope.sh 改造

现有 `scripts/compute-review-scope.sh` 写 `review-scope.yml` 决定 full vs incremental。
新增字段 `category_clusters:`，列出本轮要派发的 cluster：

```yaml
mode: incremental
changed_leaves: [...]
unchanged_leaves: [...]
category_clusters:
  - category: traceability
    criteria: [CR-PP06]
    leaves: <all leaves matching scope>
  - category: evidence
    criteria: [CR-PP07, CR-PP08, CR-PP09]
    leaves: <all leaves matching scope>
```

orchestrator 根据这个文件 fan-out N 个 cross-reviewer，每个对应一个 cluster。

### 4.4 cross-reviewer sub-agent 契约变更

`review/cross-reviewer-subagent.md`：
- 新增输入：`category` + `criteria`（cluster-scoped CR-ID 列表）
- 移除"应用所有 LLM-type CR-ID"的指令，改为"仅应用列表里的 CR-ID"
- 输出 JSON 增加 `category_applied: <category>` 字段
- create-issues.sh 把 `category_applied` 写入 issue.md 的 frontmatter（见 §6）

### 4.5 adversarial-reviewer

完全不变。Critical-trigger 量小，保持单 dispatch 简化。

## 5. Taxonomy 设计

### 5.1 PRD-analysis（7 categories）

| Category | 包含的 LLM-type CR-IDs（示例，最终以实现时核对为准） |
|----------|----------------------------------------------------|
| `traceability` | CR-PP06 |
| `evidence` | CR-PP07, CR-PP08, CR-PP09 |
| `coherence` | CR-PP12, CR-PP22, CR-PP24, CR-PP25, CR-PP26, CR-PP27 |
| `accessibility-i18n` | CR-PP28, CR-PP29, CR-PP30, CR-PP31, CR-PP32 |
| `interaction-design` | CR-PP15, CR-PP16, CR-PP17, CR-PP18, CR-PP19, CR-PP20, CR-PP21, CR-PP23, CR-PP33, CR-PP34, CR-PP38, CR-PP39 |
| `privacy-security` | CR-PP13, CR-PP43, CR-PP45 |
| `risk-governance` | CR-PP10, CR-PP11, CR-PP14, CR-PP40, CR-PP41, CR-PP42, CR-PP44 |
| `meta` | CR-META-mechanize, CR-META-adversarial |

> Formal (script-type) CR-ID 不需要 category 字段（它们走 run-checkers.sh，不进 reviewer cluster）。
> 实现期需要逐条 PRD CR 核对归类，且若发现某个 CR 跨多个 category（罕见）取"主导 category"。

### 5.2 System-design（7 categories）

| Category | 包含的 LLM-type CR-IDs（示例） |
|----------|------------------------------|
| `module-boundary` | CR-SD-DESIGN01, CR-SD-DESIGN02, CR-SD-DESIGN03 |
| `data-model` | CR-SD-DESIGN04 |
| `api-contract` | CR-SD-DESIGN05 |
| `failure-modes` | CR-SD-DESIGN06 |
| `observability` | CR-SD-DESIGN07 |
| `security` | CR-SD-DESIGN08 |
| `ui-promotion` | CR-SD-DESIGN09, CR-SD-DESIGN10, CR-SD-DESIGN11 |
| `meta` | CR-META-mechanize, CR-META-adversarial |

（同 PRD：实现期核对）

### 5.3 Taxonomy 定义文件

新增 `<skill>/common/criterion-categories.md`（**人类可读** taxonomy 定义），包含：
- 每个 category 的语义边界、典型 fix-pattern、典型反模式
- 该 category 包含的 CR-ID 列表（自动从 review-criteria.md 抽取并校对）
- 用法说明（reviewer / reviser 都应在 prompt 里收到这个文件作为上下文）

## 6. Schema 改动

### 6.1 review-criteria.md（两份）

每个 `checker_type: llm` 的 CR YAML 块新增 `category:` 字段：

```yaml
- id: CR-PP06
  name: "traceability-chain"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
  category: traceability         # ← 新增
```

`checker_type: script` 的 CR **不加** category（不走 LLM 路径）。`CR-META-*` 设为
`category: meta`。

### 6.2 issue-schema.md

`<artifact-root>/.review/round-<N>/issues/<id>.md` frontmatter 新增字段：

```yaml
category: traceability    # 必填；继承自 criterion_id 对应的 category。create-issues.sh 自动注入。
```

旧 issue 文件没有该字段时，`check-issue.sh` 应将其视为非 fatal warning（迁移期），
配套迁移脚本 `scripts/migrate-issues-add-category.sh` 一次性补齐。

### 6.3 reviewer-output JSON schema

cross-reviewer 输出 JSON 新增顶层字段：
```json
{
  "category_applied": "traceability",
  ...
}
```

`scripts/check-reviewer-output.sh` 更新 schema 校验。
`scripts/create-issues.sh` 把 `category_applied` 写入每个生成的 issue 的 `category` 字段。

## 7. 实现步骤（高层）

详细执行步骤交给 writing-plans。这里只列大块。

1. **Taxonomy 落地**
   - 写 `common/criterion-categories.md`（两个 skill 各一份）
   - 给 review-criteria.md 的每个 LLM-type CR 加 `category:`
2. **Schema + script 改造**
   - issue-schema.md 加 `category` 字段定义
   - create-issues.sh 注入 category
   - check-issue.sh 校验
   - check-reviewer-output.sh 校验 `category_applied`
   - compute-review-scope.sh 生成 `category_clusters`
3. **Reviewer 改造**
   - cross-reviewer-subagent.md prompt 重写：单 category scope + 强制输出 `category_applied`
   - review/index.md Step 2 改为按 category cluster 派发
4. **Reviser 改造**
   - per-issue-reviser-subagent.md prompt 重写：Edit-only + 多 leaf 同 criterion
   - revise/index.md Step 2 改为按 criterion 分组
   - parallel-dispatch.md Rule 3/5/6 更新（reviser 部分）
5. **测试**
   - 新增 grouping 算法 unit test（输入 N issue → 期望 K cluster）
   - 端到端：3 leaf × 5 issue 跨 2 criterion 的 revise smoke
   - review 端：8 leaf × 2 category 的 cluster 切分 smoke
   - 既有 smoke fixture 更新预期值
6. **迁移与文档**
   - migrate-issues-add-category.sh
   - CHANGELOG 写明 breaking 变更
   - SKILL.md 的 cluster 相关段落同步

## 8. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Edit unique-match 失败率高于预期 | reviser 报错 → self-loop 增加 | 形式校验脚本兜底；3 次失败升级 HITL（既有机制） |
| 一个 leaf 被 N 个 reviser 同时改导致 cache 风暴 | sub-agent 内部 cache_read 累计 | Edit cap=8 提供保护；单 reviser 内部按 leaf 顺序串行 Edit |
| Cluster 数从 4-6 增至 7-9 | dispatch 数略增 | 但 review 端总 LLM input 不增加（每 cluster 跑更少 criteria）；revise 端 sub-agent 总数取决于 criterion 分布 |
| Category 划分主观争议 | 不一致归类 | criterion-categories.md 作为单一来源；归类争议走 PR review |
| 旧 PRD/design bundle 无 category 字段 | 反向兼容 | migrate-issues-add-category.sh + check-issue.sh warning（非 fatal） |
| 写入冲突理论上仍可能 | 极少数 critical 路径错乱 | Edit 失败时 self-loop 捕获；3 失败升级 HITL |

## 9. 非 Goals

- 不改变 issue state machine（new / fixed / false-positive / deferred / superseded）
- 不改变 verdict 计算逻辑
- 不改变 --auto / --diagnose / --compact 流程
- 不改 adversarial-reviewer
- 不删除任何既有 CR-ID 或脚本
- 不改变 SKILL.md 的 Bootstrap Precheck / Phase Contract / Orchestrator Dispatch Contract 的核心契约
  （仅调整其中关于 cluster sizing 的具体规则）

## 10. 验收标准

实现完成后：

1. PRD analysis 跑一个 ≥3 feature × ≥5 issue 的 revise 轮，能正确生成按 criterion 切分的 cluster，
   每个 reviser 只使用 Edit 写入，输出形式校验通过。
2. System-design 同上。
3. review-criteria.md 中每条 LLM-type CR 都有 category 字段，criterion-categories.md 列出的 CR-ID 与
   review-criteria.md 一致（脚本可校验）。
4. 旧的 file-centric smoke fixture 仍能 pass（兼容路径）。
5. CHANGELOG 列明 breaking changes（cluster sizing 规则变更）。

---

## Appendix A: 与 SKILL.md "禁止 mega dispatch" 的关系

SKILL.md 明确禁止 orchestrator 合并多个 work unit 成一个 mega dispatch（2026-05-15 incident 教训）。
本设计**未违反**该原则：

- 当前的 work unit 定义是"一个 leaf 的所有 issue"
- 新设计的 work unit 定义改为"一个 criterion 的 ≤8 issue"
- 每个 reviser 仍然只处理一个 work unit，没有合并多个 unit
- 关键差异：work unit 的**定义**变了，不是合并了多个 unit

实现期 SKILL.md 的"Forbidden Actions"段落需要更新表述，从"per-leaf reviser dispatch"
改为"per-criterion-cluster reviser dispatch"，明确新的 unit 边界。
