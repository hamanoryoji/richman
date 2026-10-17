# RichOnline 本地化改动与工具

这是把作者 [kensou714/richonline](https://github.com/kensou714/richonline) 的服务端跑起来、并修掉两个阻塞问题后的**改动存档**。

仓库里**不包含**：

- 作者的完整源码树（请从上游获取对应快照）
- 客户端程序与资源（`RnClient.exe`、`Data/`、`Map/` 等，版权属于原厂）

仓库里**包含**：

- 对服务端源码的两处补丁（见 `patches/`）
- 本地一键启动、构建、GM 工具的脚本
- 客户端连接配置模板
- 客户端日期补丁的说明与校验值（`client-patch/README.md`，二进制不入库）
- 面向使用者的说明文档

## 背景

| 项 | 值 |
|---|---|
| 上游仓库 | https://github.com/kensou714/richonline |
| 基准快照 | 2026-10-11 的服务端归档（`服务端.zip`） |
| 客户端 | RichOnline 1.5.5（`RnClient.exe`，2009-04-02 构建，SHA256 前缀 `CB35F69F`） |
| 构建环境 | Windows + LLVM-MinGW clang 23.1.3 + CMake 4.4.4 + Ninja |

## 改动清单

### 1. 修复 libc++ 下缺少 `<exception>` 头（编译阻塞）

`server/src/richonline_game_registry.cpp` 使用了 `std::exception_ptr`，但只间接包含。libc++ 需要显式包含：

```cpp
#include <algorithm>
#include <atomic>
#include <exception>   // 新增
#include <set>
#include <utility>
```

### 2. 修复进入地图卡死（opcode 1 未被识别）

`server/src/richonline_game_startup.cpp` 的 `Startup::received()` 只把 `opcode 0` 当作「地图就绪」，
但当前客户端发的是 `opcode 1`，于是服务端干等 90 秒超时、客户端冻在加载画面。

补丁让 `1` 与 `0` 走同一条就绪路径，并保留 `map_loaded` 去重：

```cpp
if (opcode == 1) {
    if (map_loaded) return {};
    auto messages = std::vector<Bytes>{encode_richonline_board_snapshot(plan->snapshot)};
    auto opening = plan->map_ready();
    messages.insert(messages.end(), std::make_move_iterator(opening.begin()), std::make_move_iterator(opening.end()));
    auto result = output(messages);
    map_loaded = true;
    map_loading_deadline.reset();
    if (log) log("richonline_map_ready_via_opcode1");
    return result;
}
```

证据（修复前）：

```
game_admitted
richonline_map_load_wait timeout_ms=90000
richonline_game_received opcode=1 plain_bytes=2
（之后 90 秒无任何 game_transport）
```

修复后：

```
richonline_map_ready_via_opcode1
richonline_game_sent opcode=16400 ... opcode=16401 ... opcode=16911 ...
```

## 构建

```powershell
cmake -S server -B server/build -G Ninja `
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ `
  -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build server/build --parallel 8
```

`tools/build-server.ps1` 是等价的封装，会检查工具链路径。

## 运行

```powershell
server\build\RichOnline.Server.exe --data-dir <DATA_DIR> --pipe richonline-local --client-profile richonline
```

客户端：

```
RnClient.exe online-client\local.kpd 0
```

`client/local.ini` 是连接配置模板，打包成 KPD 后就是 `local.kpd`（见 `tools/kpd/`）。

## 商城为什么会“没实现”

不是没实现，是**日期策略没配对**。默认 `lobby-bootstrap.template.json` 用 `original_2005`，
购买会在扣款前被拒。要启用需要三件套：

1. 客户端打日期补丁：`RichOnline.InventoryDatePatch.exe apply RnClient.exe RnClient.datecompat.exe`
2. 数据库迁移：`RichOnline.InventoryDateMigrate.exe migrate-copy <db> <newdb> <patched-client>`
3. bootstrap 写入：

```json
"inventory_date_version": "compat_2021_v1",
"verified_client_compatibility_id": "richonline-inventory-date-2021-v1"
```

## 已知限制（来自上游，不是本仓库能修的）

- `gameReady` 仍为 `false`
- 只有 13 张 BOSS 图注册（`BS_1_1..3_4`、`V_BS_1_1`），`V_BS_1_2` 无资源
- 局内实时改数值、发道具没有控制命令（需扩展服务端）

## 许可与来源

本仓库只包含对上游代码的**补丁片段**、自写脚本与文档。
上游项目与游戏资源的版权归各自权利人所有，此处不授予额外再分发权。
