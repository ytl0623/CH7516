# CH7516 DisplayPort to LVDS Bridge - RISC-V Architecture & Chipyard Integration

本分支（`RISCV`）將 CH7516 DisplayPort to LVDS 視訊轉換核心重構成 **RISC-V SoC 架構**，遵循 [UC Berkeley Chipyard](https://github.com/ucb-bar/chipyard/releases) 架構規範，將其封裝為 **TileLink-UL (TL-UL) MMIO 外設 (Peripheral)**，並提供可在 Rocket Core 上運行的裸機 C 驅動程式與測試套件。

預設視訊來源時序與規格仍為：**1036 × 660 @ 120Hz VESA 8-bit (RGB 24bpp)**。

---

## 1. RISC-V SoC 系統架構

```
+--------------------------------------------------------------------------------+
|                           Chipyard RISC-V SoC                                  |
|                                                                                |
|  +--------------------+         +--------------------+                         |
|  | Rocket Core (CPU)  |         |      PLIC / CLINT  |                         |
|  |  RV64GC / RV32IMAC |         | (Interrupt Ctrler) |                         |
|  +---------+----------+         +---------+----------+                         |
|            |                              | interrupt                          |
|            v                              |                                    |
|  ================= TileLink System Bus (sbus/pbus) ==================          |
|            |                                                                   |
|            v (Base: 0x20000000)                                                |
|  +--------------------------------------------------------------------------+  |
|  |                 CH7516 TileLink MMIO Device (CH7516TL)                   |  |
|  |                                                                          |  |
|  |  +-----------------------------+    +---------------------------------+  |  |
|  |  | MMIO Register Bank          |    | Status & Interrupt Logic        |  |  |
|  |  | (CR, SR, HTIMING, VTIMING)  |    | (HPD, Lock, Fail, VBLANK)       |  |  |
|  |  +--------------+--------------+    +----------------+----------------+  |  |
|  |                 |                                    |                   |  |
|  |                 +------------------+-----------------+                   |  |
|  |                                    |                                     |  |
|  |                                    v                                     |  |
|  |            +-----------------------------------------------+             |  |
|  |            |   CH7516 Hardware Core (Verilog BlackBox)     |             |  |
|  |            |   - DP 4-Lane Receiver (1036x660@120Hz)       |             |  |
|  |            |   - CDC Asynchronous Video FIFO               |             |  |
|  |            |   - VESA 8-bit Formatter & 7:1 Serializer     |             |  |
|  |            +-----------------------+-----------------------+             |  |
|  +------------------------------------|-------------------------------------+  |
+---------------------------------------|----------------------------------------+
                                        v
                                 ALVTX[3:0] (Differential Data Lanes)
                                 ALVTXCLK   (Differential Clock Lane)
```

---

## 2. TileLink MMIO 暫存器映射表（Base: `0x20000000`）

| 位移 (Offset) | 暫存器名稱 | 讀/寫 | 欄位說明 |
| :---: | :---: | :---: | :--- |
| `0x00` | **`REG_CR`** | R/W | **控制暫存器 (Control Register)**<br>• `bit[0]`: 核心致能 (`CORE_EN`)<br>• `bit[1]`: 軟體復位 (`SOFT_RST`)<br>• `bit[2]`: AGMODE（`1`: 輸出 8 色階 Color Bar, `0`: 輸出 Black Panel）<br>• `bit[3]`: 格式選擇（`0`: VESA 8-bit, `1`: JEIDA 8-bit）<br>• `bit[4]`: DP 解擾碼器致能 (`SCRAMBLE_EN`) |
| `0x04` | **`REG_SR`** | RO | **狀態暫存器 (Status Register)**<br>• `bit[0]`: HPD（Hot Plug Detect 就緒狀態）<br>• `bit[1]`: FAIL_FLAG（訊號遺失 / 異常標誌）<br>• `bit[2]`: LINK_LOCKED（DP 4-Lane 訊框鎖定）<br>• `bit[3]`: STREAM_ACTIVE（視訊流主動傳輸中） |
| `0x08` | **`REG_HTIMING0`**| R/W | `bit[15:0]`: `H_ACTIVE` (**1036**)<br>`bit[31:16]`: `H_FP` (24) |
| `0x0C` | **`REG_HTIMING1`**| R/W | `bit[15:0]`: `H_SYNC` (32)<br>`bit[31:16]`: `H_BP` (48) |
| `0x10` | **`REG_VTIMING0`**| R/W | `bit[15:0]`: `V_ACTIVE` (**660**)<br>`bit[31:16]`: `V_FP` (3) |
| `0x14` | **`REG_VTIMING1`**| R/W | `bit[15:0]`: `V_SYNC` (5)<br>`bit[31:16]`: `V_BP` (12) |
| `0x18` | **`REG_TOTAL`**   | R/W | `bit[15:0]`: `H_TOTAL` (**1140**)<br>`bit[31:16]`: `V_TOTAL` (**680**) |
| `0x1C` | **`REG_IER`**     | R/W | 中斷致能暫存器 |
| `0x20` | **`REG_ISR`**     | R/W1C | 中斷狀態暫存器（寫 1 清除） |

---

## 3. Chipyard 整合檔案清單

本專案將產生器打包於 `chipyard_integration/` 目錄中，可無縫放入 Chipyard 專案：

* **Scala / Chisel 產生器**：
  * [`CH7516.scala`](file:///f:/CH7516/chipyard_integration/generators/ch7516/src/main/scala/CH7516.scala)：TileLink LazyModule、Diplomacy 節點與 Subsystem 外設整合 Trait。
  * [`CH7516BlackBox.scala`](file:///f:/CH7516/chipyard_integration/generators/ch7516/src/main/scala/CH7516BlackBox.scala)：Chisel BlackBox，整合底層 Verilog RTL。
  * [`Configs.scala`](file:///f:/CH7516/chipyard_integration/generators/ch7516/src/main/scala/Configs.scala)：Chipyard Config 片段 `WithCH7516DPLVDS`。
  * [`build.sbt`](file:///f:/CH7516/chipyard_integration/generators/ch7516/build.sbt)：sbt 模組定義。
* **RISC-V 裸機驅動與測試韌體**：
  * [`ch7516_regs.h`](file:///f:/CH7516/software/ch7516_regs.h)：MMIO 暫存器位移與 Bitmask 定義。
  * [`ch7516_driver.h`](file:///f:/CH7516/software/ch7516_driver.h) / [`ch7516_driver.c`](file:///f:/CH7516/software/ch7516_driver.c)：C 語言驅動 API。
  * [`main.c`](file:///f:/CH7516/software/main.c)：RISC-V 測試主程式。

---

## 4. 如何在官方 Chipyard 中進行編譯與模擬

參考官方發布版 [Chipyard Releases](https://github.com/ucb-bar/chipyard/releases)（例如 1.13.0 或 1.14.0）：

1. **複製產生器到 Chipyard 目錄**：
   ```bash
   cp -r chipyard_integration/generators/ch7516 <chipyard-dir>/generators/
   ```
2. **在 Chipyard `build.sbt` 加入專案依賴**：
   ```scala
   lazy val ch7516 = (project in file("generators/ch7516"))
     .dependsOn(rocketchip, cde)
     .settings(commonSettings)
   ```
3. **在 Chipyard 的 SoC 設定中使用 `WithCH7516DPLVDS`**：
   ```scala
   class RocketCH7516Config extends Config(
     new chipyard.ch7516.WithCH7516DPLVDS ++
     new freechips.rocketchip.subsystem.WithNBigCores(1) ++
     new chipyard.config.AbstractConfig
   )
   ```
4. **產生 Verilog 並使用 Verilator / VCS 模擬**：
   ```bash
   cd sims/verilator
   make CONFIG=RocketCH7516Config
   ./simulator-chipyard.harness-RocketCH7516Config <path-to-riscv-binary>
   ```

---

## 5. 本機 TileLink 模擬與驗證

專案提供完整的 TileLink-UL 匯流排模擬環境 [`tb_ch7516_riscv_tilelink.v`](file:///f:/CH7516/sim/tb_ch7516_riscv_tilelink.v)，模擬 Rocket CPU 透過 TileLink-UL 存取 MMIO 暫存器、配置 1036x660 @ 120Hz、並檢查 LVDS 差動輸出。

### 執行指令
```powershell
# PowerShell
.\sim\run_riscv_sim.ps1

# 或 Windows CMD
.\sim\run_riscv_sim.bat
```

### 驗證輸出結果
```text
================================================================================
  RISC-V Chipyard SoC: CH7516 TileLink-UL MMIO Bridge Verification
================================================================================
[INFO] Initial SR = 0x00000003
[PASS] TEST 1: TileLink read confirmed HPD is asserted.
[PASS] TEST 2: TileLink wrote and verified H_ACTIVE=1036, H_FP=24.
[PASS] TEST 3: CR successfully configured with AGMODE BIST enabled.
[PASS] TEST 4: TileLink Status Register confirmed DP Link Locked.
[PASS] TEST 5: Differential LVDS signaling active and balanced.
================================================================================
 RISC-V TILELINK VERIFICATION SUMMARY: 5 Passed, 0 Failed
 RESULT: *** ALL RISC-V TILELINK MMIO TESTS PASSED! ***
================================================================================
```
