USE [MicrosoftRDB];
GO

-- 1. 維度表 (Dimension Tables)
CREATE TABLE [dbo].[RegionsMaster](
    [RegionID] INT PRIMARY KEY,
    [RegionCode] NVARCHAR(10) NOT NULL UNIQUE,
    [RegionName] NVARCHAR(100) NOT NULL,
    [CreatedAt] DATETIME DEFAULT GETDATE()
);

CREATE TABLE [dbo].[KeywordsMaster](
    [KeywordID] INT PRIMARY KEY,
    [Keyword] NVARCHAR(200) NOT NULL UNIQUE,
    [Category] NVARCHAR(50),
    [SearchIntent] NVARCHAR(50),
    [CreatedAt] DATETIME DEFAULT GETDATE()
);

CREATE TABLE [dbo].[DimDate](
    [DateKey] INT PRIMARY KEY,
    [FullDateTime] DATETIME2(2) NOT NULL,
    [DateYear] INT,
    [DateMonth] INT,
    [DateDay] INT,
    [DateHour] INT,
    [DateWeekday] INT
);

-- 2. 狀態與日誌表 (Log & Staging Tables)
CREATE TABLE [dbo].[KeywordsLog](
    [LogID] INT PRIMARY KEY,
    [KeywordID] INT NOT NULL REFERENCES [dbo].[KeywordsMaster](KeywordID),
    [LogDate] DATE NOT NULL,
    [CrawlTime] DATETIME DEFAULT GETDATE(),
    [SummaryText] NVARCHAR(MAX),
    [Status] NVARCHAR(50),
    [ErrorMessage] NVARCHAR(1000),
    [CreatedAt] DATETIME DEFAULT GETDATE()
);

CREATE TABLE [dbo].[CrawlerExecutionLog](
    [ExecutionID] INT PRIMARY KEY,
    [ExecutionDate] DATE NOT NULL,
    [StartTime] DATETIME NOT NULL,
    [EndTime] DATETIME,
    [DurationSeconds] INT,
    [RegionsScraped] INT DEFAULT 0,
    [TotalKeywordsFound] INT DEFAULT 0,
    [NewKeywordsAdded] INT DEFAULT 0,
    [KeywordsSearched] INT DEFAULT 0,
    [Status] NVARCHAR(50) DEFAULT N'執行中',
    [ErrorMessage] NVARCHAR(MAX),
    [CrawlerVersion] NVARCHAR(50),
    [PythonVersion] NVARCHAR(50),
    [CreatedAt] DATETIME DEFAULT GETDATE(),
    [UpdatedAt] DATETIME
);

-- 3. 核心事實表 (Core Fact Tables)
CREATE TABLE [dbo].[KeywordRegionStats](
    [StatsID] INT PRIMARY KEY,
    [KeywordID] INT NOT NULL REFERENCES [dbo].[KeywordsMaster](KeywordID),
    [RegionID] INT NOT NULL REFERENCES [dbo].[RegionsMaster](RegionID),
    [LogDate] DATE NOT NULL,
    [SearchVolume] INT,
    [AppearanceCount] INT DEFAULT 1,
    [TrendRank] INT,
    [CreatedAt] DATETIME DEFAULT GETDATE()
);

CREATE TABLE [dbo].[DailyTrendSnapshots](
    [SnapshotID] INT PRIMARY KEY,
    [KeywordID] INT NOT NULL REFERENCES [dbo].[KeywordsMaster](KeywordID),
    [RegionID] INT NOT NULL REFERENCES [dbo].[RegionsMaster](RegionID),
    [SnapshotDate] DATE NOT NULL,
    [SnapshotTime] DATETIME DEFAULT GETDATE(),
    [SearchVolume] INT,
    [TrendRank] INT,
    [RankChange] INT,
    [VolumeChangeRate] DECIMAL(10, 2),
    [IsNewEntry] BIT DEFAULT 0,
    [CreatedAt] DATETIME DEFAULT GETDATE(),
    CONSTRAINT [UQ_Snapshot_Daily] UNIQUE ([KeywordID], [RegionID], [SnapshotDate])
);

-- 4. 數據品質監控表 (Data Quality Tables)
CREATE TABLE [dbo].[DataQualityLog](
    [QualityID] INT PRIMARY KEY,
    [CheckDate] DATE NOT NULL,
    [CheckTime] DATETIME DEFAULT GETDATE(),
    [RegionID] INT REFERENCES [dbo].[RegionsMaster](RegionID),
    [TotalKeywords] INT DEFAULT 0,
    [KeywordsWithVolume] INT DEFAULT 0,
    [KeywordsWithRank] INT DEFAULT 0,
    [NewKeywords] INT DEFAULT 0,
    [VolumeCompleteness] DECIMAL(5, 2),
    [RankCompleteness] DECIMAL(5, 2),
    [CategoryCompleteness] DECIMAL(5, 2),
    [ErrorCount] INT DEFAULT 0,
    [WarningCount] INT DEFAULT 0,
    [OverallStatus] NVARCHAR(20) DEFAULT N'正常',
    [Comments] NVARCHAR(1000),
    [CreatedAt] DATETIME DEFAULT GETDATE()
);
GO