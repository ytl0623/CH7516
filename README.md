# CH7516 DisplayPort to 4-Channel LVDS Converter (Verilog HDL)

本專案參考 **Chrontel CH7516A 4 Lane DisplayPort to 4 Channel LVDS Converter** 資料手冊規格，使用純硬體描述語言（Verilog HDL）完整實作了 DisplayPort 到 LVDS 的轉換核心，並完成自我檢查（Self-Checking）測試平台的完整功能驗證。

預設視訊來源時序與規格設定為：**1036 × 660 @ 120Hz VESA 8-bit (RGB 24bpp)**。

---

## 1. 系統架構設計 (System Architecture)

```
       +-------------------------------------------------------------------------+
       |                     CH7516 DP to LVDS Top Core                          |
       |                                                                         |
DP RX  |  +--------------------+    +-------------------+    +----------------+  |
Lanes  |  |   8b/10b Decoder   |--->|  DP Descrambler   |--->| Pixel Unpacker |  |
[3:0] ===>|  (dp_8b10b_dec)    |    |  (dp_descrambler) |    |  (4-lane RGB8) |  |
       |  +--------------------+    +-------------------+    +-------+--------+  |
       |                                                             |           |
       |                                              (96-bit word / 4-pixel)    |
       |                                                             v           |
       |                                                    +-----------------+  |
       |                                                    | Asynchronous    |  |
       |                                                    | Video FIFO      |  |
       |                                                    | (CDC Dual Clock)|  |
       |                                                    +--------+--------+  |
       |                                                             |           |
       |    +--------------------+                          +--------v--------+  |
       |    | Video Timing Gen   |------------------------->| Video Stream    |  |
       |    | (1036x660 @ 120Hz) |                          | Multiplexer     |  |
       |    +---------+----------+                          +--------+--------+  |
       |              |                                              |           |
       |              v                                              v           |
       |    +--------------------+                          +-----------------+  |
       |    | BIST Generator     |------------------------->| LVDS Formatter  |  |
       |    | (Color Bar/Black)  |                          | (VESA 8-bit)    |  |
       |    +--------------------+                          +--------+--------+  |
       |                                                             | (7-bit)   |
       |                                                    +--------v--------+  |  LVDS TX
       |                                                    | 7:1 Serializer  |===> ALVTX[3:0]
       |                                                    | (Diff Drivers)  |===> ALVTXCLK
       |                                                    +-----------------+  |
       +-------------------------------------------------------------------------+
```

### 核心模組組成
1. **`dp_8b10b_decoder.v`**:
   - 支援 10b 到 8b 解碼，自動識別 DP 專用控制字元：
     - `K28.5 (0xBC)`: Blanking Start (BS)
     - `K27.7 (0xFB)`: Blanking End (BE)
     - `K28.2 (0x4C)`: Fill Start (FS) / Secondary Start (SS)
     - `K29.7 (0xFD)`: Fill End (FE) / Secondary End (SE)
     - `K28.0 (0x1C)`: Scrambler Reset (SR)
2. **`dp_descrambler.v`**:
   - 符合 DP 1.2 / eDP 規格的 LFSR 解擾碼器：多項式 $G(X) = X^{16} + X^{15} + X^{13} + X^4 + 1$。
   - 支援 Enhanced Framing Mode，依 Lane 索引載入特定種子（Seed：Lane 0 `0xFFFF`, Lane 1 `0xFFFE`, Lane 2 `0xFFFD`, Lane 3 `0xFFFC`）。
3. **`dp_pixel_unpacker_4lane.v`**:
   - 完整解析 DP Main Link 訊框（Framing），提取 VB-ID 與消隱區狀態。
   - 針對 4-Lane RGB 8-bit（24bpp），每 3 個 Link Clock 週期完整解出 4 個連續 RGB 像素，以 96-bit 寬度原子化輸出。
   - 完美吻合 $1036$ 點的水平解析度（$1036 \div 4 = 259$ 組，完全整除）。
4. **`video_async_fifo.v`**:
   - 跨時脈域（CDC）雙時脈非同步 FIFO，深度 512 筆（可緩衝 2048 像素，近 2 個完整行）。
   - 採用 Gray Code 指標與雙級正反器同步，杜絕亞穩態（Metastability）。
5. **`video_timing_generator.v`**:
   - 產生標準 $1036 \times 660 @ 120\text{Hz}$ 光柵時序（DE, HSYNC, VSYNC）。
6. **`video_bist_pattern.v`**:
   - 依據 CH7516 晶片特性實作：
     - `AGMODE = 1`: 產生標準 8 色階 Color Bar（白、黃、青、綠、洋紅、紅、藍、黑）。
     - `AGMODE = 0`: 輸入無效時自動切換至純黑畫面（Black Panel）。
7. **`lvds_formatter_vesa8.v`**:
   - 將 24-bit RGB 像素映射為 4 組 7-bit LVDS 並列資料。
   - 支援 VESA (SPWG) 8-bit 與 JEIDA (OpenLDI) 8-bit 切換。
8. **`lvds_serializer_7to1.v`**:
   - 7:1 串列化器，以 `lvds_bit_clk`（7倍像素時脈）移位輸出差動訊號對（`_p`, `_n`）。
9. **`ch7516_dp_to_lvds_top.v`**:
   - 頂層整合模組，完整對應 CH7516A 腳位（RSTB, HPD, FAIL_FLAG_OUT, ALVTX 等）。

---

## 2. 視訊時序參數 (1036x660 @ 120Hz)

| 參數名稱 | 符號 / 定義 | 數值 (像素 / 行數) | 說明 |
| :--- | :--- | :--- | :--- |
| **Horizontal Active** | `H_ACTIVE` | **1036** | 水平有效顯示區域 |
| **Horizontal Front Porch** | `H_FP` | 24 | 水平前沿 |
| **Horizontal Sync Pulse** | `H_SYNC` | 32 | 水平同步脈衝寬度 |
| **Horizontal Back Porch** | `H_BP` | 48 | 水平後沿 |
| **Horizontal Total** | `H_TOTAL` | **1140** | 水平總週期 |
| **Vertical Active** | `V_ACTIVE` | **660** | 垂直有效顯示行數 |
| **Vertical Front Porch** | `V_FP` | 3 | 垂直前沿 |
| **Vertical Sync Pulse** | `V_SYNC` | 5 | 垂直同步脈衝行數 |
| **Vertical Back Porch** | `V_BP` | 12 | 垂直後沿 |
| **Vertical Total** | `V_TOTAL` | **680** | 垂直總行數 |
| **畫面更新率** | `Refresh Rate` | **120 Hz** | 每秒 120 張畫面 |
| **像素時脈 (Pixel Clock)** | $f_{\text{pixel}}$ | **93.024 MHz** | $1140 \times 680 \times 120\text{Hz}$ |
| **LVDS 串列位元時脈** | $f_{\text{bit}}$ | **651.168 MHz** | $7 \times f_{\text{pixel}}$ |

> **說明**：CH7516A 資料手冊載明：「Single LVDS port supports up to 140MHz pixel clock frequency」，因此 $93.024\text{ MHz}$ 可由單一 LVDS 通道（Channel A: ALVTX[3:0] + ALVTXCLK）完美驅動，無須 Dual-Link 拆分。

---

## 3. VESA 8-bit (SPWG) 與 JEIDA 8-bit 映射表

### VESA 8-bit 模式 (`cfg_lvds_format = 0`，預設)
| 週期時隙 (Slot) | Data Lane 0 (ALVTX0) | Data Lane 1 (ALVTX1) | Data Lane 2 (ALVTX2) | Data Lane 3 (ALVTX3) | Clock Lane (ALVTXCLK) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Bit 0** | R[0] | G[1] | B[2] | R[6] | 1 |
| **Bit 1** | R[1] | G[2] | B[3] | R[7] | 1 |
| **Bit 2** | R[2] | G[3] | B[4] | G[6] | 0 |
| **Bit 3** | R[3] | G[4] | B[5] | G[7] | 0 |
| **Bit 4** | R[4] | G[5] | HSYNC | B[6] | 0 |
| **Bit 5** | R[5] | B[0] | VSYNC | B[7] | 1 |
| **Bit 6** | G[0] | B[1] | DE | 0 (RSV) | 1 |

---

## 4. 驗證結果與執行方式

### 執行模擬指令
在專案目錄下執行 PowerShell 或 Batch 腳本：
```powershell
# PowerShell
.\sim\run_all_tests.ps1

# 或 Windows CMD
.\sim\run_all_tests.bat
```

### 驗證項目涵蓋
- **測試 1**: 復位釋放後 HPD 腳位正確拉高（通知 DP Source 連線就緒）。
- **測試 2**: DP 輸入未就緒時，`fail_flag_out` 正確拉高警告。
- **測試 3**: BIST 模式（`AGMODE = 1`）產生標準 8 色階 Color Bar，LVDS 輸出 Clock Pattern 符合 OpenLDI `7'b1100011`。
- **測試 4**: DP 4-Lane Main Link 訊框接收，偵測 BS/BE 建立 Link Lock 與 Stream Active。
- **測試 5**: 跨時脈域非同步 FIFO 寫入與讀出無丟包，水位穩定。
- **測試 6**: LVDS 接收端重建解碼，1036 水平畫素逐點色彩精確比對無誤。
- **測試 7**: ALVTX[3:0] 與 ALVTXCLK 差動訊號對真值比對（P 與 N 嚴格互補）。
- **測試 8**: 動態切換為 JEIDA 8-bit 格式。
- **測試 9**: 斷訊時自動切回 Black Panel 防呆保護。
- **單元測試**: 8b/10b 解碼器、LFSR 擾碼器種子載入與真值表 100% 通過。
