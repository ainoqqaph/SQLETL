USE [MicrosoftRDB];
GO

-- 1. 生成 Power BI 專用 Fact 表 (含 DateKey 生成邏輯)
CREATE VIEW [dbo].[vw_FactDailyTrends] AS
SELECT 
    s.SnapshotID,
    CAST(
        CAST(YEAR(s.SnapshotDate) AS VARCHAR(4)) +
        RIGHT('0' + CAST(MONTH(s.SnapshotDate) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DAY(s.SnapshotDate) AS VARCHAR(2)), 2) +
        '00' AS INT
    ) AS DateKey,
    s.KeywordID,
    s.RegionID,
    s.SearchVolume,
    s.TrendRank,
    s.RankChange,
    s.VolumeChangeRate,
    1 AS AppearanceCount,
    CASE WHEN s.IsNewEntry = 1 THEN 1 ELSE 0 END AS NewEntryCount,
    CASE WHEN s.RankChange > 0 THEN 1 ELSE 0 END AS RisingKeywordCount,
    1 AS RecordCount
FROM dbo.DailyTrendSnapshots s;
GO

-- 2. 爬蟲執行與資料品質監控儀表板
CREATE VIEW [dbo].[vw_DataQualityDashboard] AS
SELECT 
    dq.CheckDate,
    r.RegionCode,
    r.RegionName,
    dq.TotalKeywords,
    dq.KeywordsWithVolume,
    dq.KeywordsWithRank,
    dq.NewKeywords,
    dq.VolumeCompleteness,
    dq.RankCompleteness,
    dq.CategoryCompleteness,
    dq.ErrorCount,
    dq.WarningCount,
    dq.OverallStatus,
    dq.Comments,
    CASE 
        WHEN dq.OverallStatus = N'正常' THEN 'Pass'
        WHEN dq.OverallStatus = N'警告' THEN 'Warn'
        WHEN dq.OverallStatus = N'嚴重' THEN 'Fail'
        ELSE 'Unknown'
    END AS StatusIcon
FROM dbo.DataQualityLog dq
LEFT JOIN dbo.RegionsMaster r ON dq.RegionID = r.RegionID;
GO

-- 3. 找出爆發成長的高價值關鍵字
CREATE VIEW [dbo].[vw_TopRisingKeywords] AS
SELECT TOP 100
    s.SnapshotDate,
    r.RegionName,
    k.Keyword,
    k.Category,
    s.TrendRank AS CurrentRank,
    s.RankChange,
    s.SearchVolume,
    s.VolumeChangeRate,
    s.IsNewEntry
FROM DailyTrendSnapshots s
INNER JOIN KeywordsMaster k ON s.KeywordID = k.KeywordID
INNER JOIN RegionsMaster r ON s.RegionID = r.RegionID
WHERE s.RankChange > 0 OR s.IsNewEntry = 1
ORDER BY s.SnapshotDate DESC, s.RankChange DESC;
GO