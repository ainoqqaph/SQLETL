# 企業級自動化資料倉儲與 ETL 數據管線 (Enterprise Data Warehouse & ETL Pipeline)

本專案為「跨國市場情報戰情室」的底層核心資料庫架構。採用 Microsoft SQL Server，遵循星狀模型 (Star Schema) 設計，並結合進階 T-SQL 預存程序 (Stored Procedures) 實現全自動化的 ETL (Extract, Transform, Load) 流程與數據品質監控。

### 1. 星狀模型資料倉儲設計 (Star Schema Design)
- 維度表 (Dimension Tables)：建立 KeywordsMaster、RegionsMaster、DimDate，將商業意圖、產業分類與地理資訊標準化。
- 事實表 (Fact Tables & Views)：透過 View 動態生成 vw_FactDailyTrends、vw_FactKeywordRelations，自動將時間轉換為 yyyyMMddHH 格式的 DateKey，完美對接 Power BI 等前端 BI 工具的關聯模型。

### 2. 高併發與防鎖死機制 (Concurrency & Deadlock Prevention)
- 捨棄傳統容易引發 Table Lock 的 MERGE 語法，改用 UPDATE 與 INSERT ... WHERE NOT EXISTS 的冪等性 (Idempotent) 寫入邏輯，確保多次執行不會產生重複資料。
- 於 Python 爬蟲端與 SQL 端結合 BEGIN TRANSACTION 與 WITH (UPDLOCK, SERIALIZABLE) 排他鎖，解決多執行緒批次寫入時的 Deadlock 問題。

### 3. 智慧補抓與 Append-Only 日誌追蹤
- 實作 Append-Only 的 KeywordsLog 日誌表，完整記錄爬蟲的每一次成功與失敗軌跡。
- 開發智慧補抓邏輯：WHERE KeywordID NOT IN (SELECT KeywordID FROM KeywordsLog WHERE Status = 'Success')，確保自動化排程 (Airflow) 只針對尚未成功的目標進行重試，不破壞歷史錯誤現場。

### 4. 內建資料品質監控 (Data Quality Monitoring, DQM)
- 開發 usp_CheckDataQuality_Enhanced 預存程序，每日自動掃描資料庫。
- 動態計算「搜尋量完整度」、「排名完整度」與「分類覆蓋率」，當完整度低於 80% 或資料筆數異常時，自動觸發 Alert 寫入 QualityAlerts 告警表。

## 資料夾結構 (Repository Structure)
- DDL_Tables.sql: 基礎資料表建置 (Tables, PK/FK, Default Constraints)
- DQL_Views.sql: 商業智慧檢視表 (BI Fact/Dim Views, 異常監控視圖)
- DML_StoredProcedures.sql: ETL 處理、資料清洗與品質監控預存程序
