# 客户端补丁（独立管理）

本目录保存对 `RnClient.exe` 的日期兼容补丁及其校验清单。**不进入代码仓库**，
因为它是 4.7 MB 二进制 + 3 字节改动，git 无法有效 diff，也涉及原厂版权。

## 补丁做了什么

把客户端内部的道具日期纪元从 2005 改为 2021，使商城可用的年份区间变成 2021–2036。
只改 3 个字节，偏移固定：

| 文件偏移 | 说明 |
|---|---|
| 0x145D55 | 日期纪元常量 |
| 0x146A7A | 同上 |
| 0x14D2F7 | 同上 |

## 校验值

| 项 | SHA256 |
|---|---|
| 原版 `RnClient.exe`（2009-04-02 构建） | `CB35F69F3D49C2093897D4EA2CB547A1E38B213F3A8DF0AF52B859F9E661DE77` |
| 补丁后 `RnClient.datecompat.exe` | `68CE9D7EA5395E437B703D7A5B0F47265666D6EF069CF04A2281BB76F0822FF2` |
| 兼容标识 | `richonline-inventory-date-2021-v1` |

原版哈希对不上时**不要**打补丁——说明客户端版本不同，偏移量不保证成立。

## 目录内容

```
README.md                       本说明
RnClient.datecompat.exe         补丁后的客户端（可直接用）
RnClient.datecompat.json        生成工具输出的清单（哈希、偏移、纪元）
InventoryDatePatch.exe          打补丁工具（来自上游 server/tools）
apply-date-patch.ps1            一键：校验 → 打补丁 → 覆盖原文件
```

## 怎么用

**直接替换**（最常用）：

```
把 RnClient.datecompat.exe 复制到客户端目录，改名为 RnClient.exe
原文件先留一份 RnClient.exe.orig-2005
```

**重新生成**（换了客户端或想复核）：

```powershell
.\apply-date-patch.ps1 -ClientDir "D:\...\Richonline"
```

脚本会先校验当前 `RnClient.exe` 的 SHA256，只有匹配原版哈希才动手；
生成后再次校验，成功才覆盖，失败保留原文件。

## 回滚

把 `RnClient.exe.orig-2005` 复制回 `RnClient.exe` 即可。
注意：只回滚客户端不够——服务端 bootstrap 的 `inventory_date_version` 也要改回
`original_2005`，否则日期策略与客户端不一致，购买仍会被拒。

## 与服务端的配套关系

三者必须一致，缺一不可：

| 层 | 要求 |
|---|---|
| 客户端 | 本文档的补丁（纪元 2021） |
| 数据库 | `metadata.inventory_date_version = richonline-inventory-date-2021-v1` |
| 服务端配置 | `richonline_mall_policy.inventory_date_version = compat_2021_v1`<br>`verified_client_compatibility_id = richonline-inventory-date-2021-v1` |
