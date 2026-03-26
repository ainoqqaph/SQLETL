USE [MicrosoftRDB];
GO

-- 1. 每日趨勢快照 (Idempotent Upsert 架構)
CREATE PROCEDURE [dbo].[usp_InsertDailySnapshots]
    @SnapshotDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @SnapshotDate IS NULL SET @SnapshotDate = CAST(GETDATE() AS DATE);
    
    -- 取得當日最佳排名與最大流量
    SELECT krs.KeywordID, krs.RegionID, MAX(krs.SearchVolume) AS SearchVolume, MIN(krs.TrendRank) AS TrendRank
    INTO #TempSnapshots
    FROM dbo.KeywordRegionStats krs
    WHERE krs.LogDate = @SnapshotDate
    GROUP BY krs.KeywordID, krs.RegionID;

    -- 步驟 1：更新已存在記錄 (防止重複)
    UPDATE target
    SET SearchVolume = source.SearchVolume, TrendRank = source.TrendRank, SnapshotTime = GETDATE()
    FROM dbo.DailyTrendSnapshots target
    INNER JOIN #TempSnapshots source ON target.KeywordID = source.KeywordID AND target.RegionID = source.RegionID
    WHERE target.SnapshotDate = @SnapshotDate;
    
    -- 步驟 2：寫入新記錄
    INSERT INTO dbo.DailyTrendSnapshots (SnapshotID, KeywordID, RegionID, SnapshotDate, SearchVolume, TrendRank)
    SELECT ISNULL((SELECT MAX(SnapshotID) FROM dbo.DailyTrendSnapshots), 0) + ROW_NUMBER() OVER(ORDER BY source.KeywordID),
           source.KeywordID, source.RegionID, @SnapshotDate, source.SearchVolume, source.TrendRank
    FROM #TempSnapshots source
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.DailyTrendSnapshots target
        WHERE target.KeywordID = source.KeywordID AND target.RegionID = source.RegionID AND target.SnapshotDate = @SnapshotDate
    );
    DROP TABLE #TempSnapshots;
END;
GO

-- 2. 增強版資料品質監控 (DQM)
CREATE PROCEDURE [dbo].[usp_CheckDataQuality_Enhanced]
    @CheckDate DATE = NULL,
    @RegionID INT = NULL,
    @EnableAlert BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @CheckDate IS NULL SET @CheckDate = CAST(GETDATE() AS DATE);
    
    DECLARE @TotalKeywords INT, @KeywordsWithVolume INT, @KeywordsWithRank INT, @KeywordsWithCategory INT;
    DECLARE @VolumeComp DECIMAL(5,2), @OverallStatus NVARCHAR(20) = N'正常', @Comments NVARCHAR(1000) = '';
    
    -- 統計
    SELECT @TotalKeywords = COUNT(DISTINCT KeywordID),
           @KeywordsWithVolume = COUNT(DISTINCT CASE WHEN SearchVolume IS NOT NULL THEN KeywordID END)
    FROM dbo.KeywordRegionStats WHERE LogDate = @CheckDate AND (@RegionID IS NULL OR RegionID = @RegionID);
    
    SET @VolumeComp = CASE WHEN @TotalKeywords > 0 THEN (@KeywordsWithVolume * 100.0 / @TotalKeywords) ELSE 0 END;
    
    -- 告警邏輯
    IF @VolumeComp < 80 
    BEGIN
        SET @Comments = @Comments + N'搜尋量嚴重不足(' + CAST(CAST(@VolumeComp AS DECIMAL(5,1)) AS NVARCHAR(10)) + '%); ';
        SET @OverallStatus = N'嚴重';
    END
    IF @TotalKeywords < 50 
    BEGIN
        SET @Comments = @Comments + N'抓取數量偏低(' + CAST(@TotalKeywords AS NVARCHAR(10)) + '); ';
        IF @OverallStatus != N'嚴重' SET @OverallStatus = N'警告';
    END
    IF LEN(@Comments) = 0 SET @Comments = N'數據品質優良';

    -- 記錄寫入
    DELETE FROM dbo.DataQualityLog WHERE CheckDate = @CheckDate AND (RegionID = @RegionID OR (RegionID IS NULL AND @RegionID IS NULL));
    INSERT INTO dbo.DataQualityLog (QualityID, CheckDate, RegionID, TotalKeywords, KeywordsWithVolume, VolumeCompleteness, OverallStatus, Comments)
    VALUES (ISNULL((SELECT MAX(QualityID) FROM dbo.DataQualityLog), 0) + 1, @CheckDate, @RegionID, @TotalKeywords, @KeywordsWithVolume, @VolumeComp, @OverallStatus, @Comments);
END;
GO