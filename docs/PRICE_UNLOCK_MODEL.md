# G Token 价格解锁模型

## 当前模式：后端签名授权型价格解锁

### 架构

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Backend      │────▶│ 用户 dApp    │────▶│ TON 链上合约 │
│ 价格服务     │     │ TON Connect  │     │ G_Sale/Team  │
└──────┬──────┘     └──────────────┘     └──────┬──────┘
       │                                        │
       │ 1. 查询价格                             │ 3. 验签 + 发币
       │ 2. 签授权                              │
       └────────────────────────────────────────┘
```

### 流程

1. **后端价格服务**定期查询 DEX/预言机获取 G 的 USD 价格
2. 后端验证：当前价格 ≥ 目标价 且 已维持 24 小时
3. 验证通过后，后端用 Ed25519 私钥对 claim payload 签名
4. 用户通过 dApp 将签名后的消息发送到链上合约
5. **合约验签通过即释放**，不自行查询 PriceOracle

### 链上合约验证的内容

- ✅ Ed25519 签名有效性（`isSignatureValid`）
- ✅ 签名未过期（`expiresAt`）
- ✅ nonce 未重复使用（防重放）
- ✅ 轮次在配置范围内（`roundNumber ≤ totalRounds`）
- ✅ 该轮次未被领取过（`claimedMask`）
- ✅ 金额与配置匹配（`gAmount == roundGAmount`）
- ❌ 不验证当前价格是否 ≥ 目标价（由后端签名时保证）
- ❌ 不验证价格是否维持 24 小时（由后端签名时保证）

### PriceOracle 的当前角色

`PriceOracle` 合约是**辅助记录工具**，不是 claim 的强制条件：

- 管理员调用 `updatePrice(usdPrice)` 写入当前价格
- `updatePrice` 自动更新已注册目标价的 `firstReachTime`
- 任何合约/用户可通过 `check_target(targetPrice)` getter 查询（off-chain only）
- **G_Sale 和 G_TeamVesting 的 claim 路径不查询 PriceOracle**

### 为什么选择这个模式

| 优势 | 说明 |
|------|------|
| 实现简单 | 不需要异步 Oracle 查询→回调的复杂消息链 |
| Gas 友好 | claim 只需一次交易，不需要等待 Oracle 响应 |
| 安全可控 | 后端私钥泄露需要同时攻破后端 + 私钥 |
| 运维灵活 | 价格来源可切换 DEX/CEX/自定义，无需升级合约 |

| 风险 | 缓解措施 |
|------|---------|
| 后端单点 | 私钥硬件保护 + 多签升级路线 |
| 价格操纵 | 后端使用 TWAP + 多源价格聚合 |
| 签名泄露 | Ed25519 签名包含 `expiresAt`（短期有效）+ `contractAddress`（跨合约不可重放） |

### 签名域隔离

为防止签名跨合约/跨网络重放，所有签名 payload 包含：

| 字段 | 说明 |
|------|------|
| `chainId` | 工作链 ID（0 = basechain） |
| `schemaVersion` | 签名格式版本号（当前 = 1） |
| `contractAddress` | 目标合约地址（防止 Sale A 签名用于 Sale B） |

### 后端的价格验证职责

部署后，后端价格服务必须：

1. 定期从数据源获取 G 的 USD 价格
2. 对每个未解锁轮次，检查：`currentPrice ≥ targetPrice`
3. 如果目标价首次达到，记录 `firstReachTime = now`
4. 如果价格跌破目标价，重置 `firstReachTime = 0`
5. 只有当 `firstReachTime ≠ 0` 且 `now - firstReachTime ≥ 86400` 时，才签发 claim 签名

---

## 后续升级路线：链上 Oracle 状态型解锁

如果未来需要纯链上价格强制解锁，升级路径：

1. **Oracle 推送模式**：PriceOracle 在 `updatePrice` 时主动向 Sale/Team 合约发送已解锁轮次通知
2. **Sale/Team 存储 Oracle 状态**：合约本地记录"某轮次已解锁"
3. **Claim 只读本地状态**：不需要后端签名，只要本地 `unlockedRounds[round] == true`
4. **需要链上维护机器人**：定期调用 `updatePrice` 触发状态推送

此升级需要合约代码变更（无代理模式 = 重新部署）。

---

## 对外口径

在官网、白皮书、dApp 中，必须诚实说明：

> G Token 的价格解锁采用**后端授权签名模式**。后端价格服务验证"目标价达到并维持 24 小时"后签发授权签名。链上合约验证签名有效性、防重放和轮次限制后释放代币。PriceOracle 作为链上价格记录和审计辅助。

禁止表述为"完全链上自动价格解锁"。
