# business-analysis.ps1 (ASCII only in source - avoids encoding issues)
# Read-only business analysis for Al-Ameen (AmnMwh26). No data is changed.
# Classifies documents using bt000.BillType: 1=Sales, 3=Sales Return, 0+bNoEntry=0 => Purchases.
# Output: a single flat text report, easy to copy-paste back for analysis.

$ErrorActionPreference = "Stop"
$cs = "Server=localhost;Database=AmnMwh26;Integrated Security=True;TrustServerCertificate=True"
$outDir = "$env:USERPROFILE\Desktop\AmnAudit"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = "$outDir\business-analysis.txt"

function Run-Query($sql) {
    $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandTimeout = 120
        $cmd.CommandText = $sql
        $ad = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        [void]$ad.Fill($dt)
        return ,$dt
    } finally { $conn.Close() }
}

function Dump($dt) {
    $out = @()
    $out += ($dt.Columns | ForEach-Object { $_.ColumnName }) -join "`t"
    foreach ($r in $dt.Rows) {
        $vals = @()
        foreach ($c in $dt.Columns) { $vals += [string]$r[$c.ColumnName] }
        $out += ($vals -join "`t")
    }
    return $out
}

# Arabic keywords built from Unicode code points (keeps this file pure ASCII).
$kwSalesPrefix = (-join @([char]0x0645,[char]0x0628,[char]0x064A,[char]0x0639,[char]0x0627,[char]0x062A)) + " " + (-join @([char]0x0633,[char]0x064A,[char]0x0627,[char]0x0631,[char]0x0629))  # "mabee'at sayyara" (van sales)
$kwGifts = (-join @([char]0x0647,[char]0x062F,[char]0x0627,[char]0x064A,[char]0x0627)) + " " + (-join @([char]0x0648,[char]0x0639,[char]0x0631,[char]0x0648,[char]0x0636))  # "hadaya wa 'urood" (gifts and promotions)

$report = @()
$report += "AL-AMEEN BUSINESS ANALYSIS - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$report += "Period: last 12 months"
$report += ""

# 1. Monthly net sales and returns
$report += "=== 1. MONTHLY SALES AND RETURNS (last 12 months) ==="
$q1 = "SELECT CONVERT(varchar(7), bu.Date, 120) AS Month, SUM(CASE WHEN bt.BillType=1 THEN bu.Total ELSE 0 END) AS GrossSales, SUM(CASE WHEN bt.BillType=3 THEN bu.Total ELSE 0 END) AS Returns FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType IN (1,3) AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY CONVERT(varchar(7), bu.Date, 120) ORDER BY Month"
$report += (Dump (Run-Query $q1))
$report += ""

# 2. Monthly profit (from sales lines)
$report += "=== 2. MONTHLY NET PROFIT (from sales lines, last 12 months) ==="
$q2 = "SELECT CONVERT(varchar(7), bu.Date,120) AS Month, SUM(bi.Netprofit) AS Profit FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY CONVERT(varchar(7), bu.Date,120) ORDER BY Month"
$report += (Dump (Run-Query $q2))
$report += ""

# 3. Top 20 products by revenue
$report += "=== 3. TOP 20 PRODUCTS BY REVENUE (last 12 months) ==="
$q3 = "SELECT TOP 20 mt.Name, SUM(bi.Qty) AS TotalQty, SUM(bi.Qty*bi.Price) AS Revenue, SUM(bi.Netprofit) AS Profit FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN mt000 mt ON mt.GUID=bi.MatGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY mt.Name ORDER BY Revenue DESC"
$report += (Dump (Run-Query $q3))
$report += ""

# 4. Top 20 customers by sales
$report += "=== 4. TOP 20 CUSTOMERS BY SALES VALUE (last 12 months) ==="
$q4 = "SELECT TOP 20 cu.CustomerName, COUNT(*) AS InvoiceCount, SUM(bu.Total) AS Revenue FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN cu000 cu ON cu.GUID=bu.CustGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY cu.CustomerName ORDER BY Revenue DESC"
$report += (Dump (Run-Query $q4))
$report += ""

# 5. Top 20 customers by outstanding debt
$report += "=== 5. TOP 20 CUSTOMERS BY OUTSTANDING DEBT (current) ==="
$q5 = "SELECT TOP 20 cu.CustomerName, cu.Debit, cu.Credit, (cu.Debit-cu.Credit) AS Balance FROM cu000 cu WHERE cu.bHide = 0 ORDER BY Balance DESC"
$report += (Dump (Run-Query $q5))
$report += ""

# 6. Van performance
$report += "=== 6. VAN/ROUTE PERFORMANCE (last 12 months) ==="
$q6 = "SELECT bt.Name AS Van, COUNT(*) AS InvoiceCount, SUM(bu.Total) AS Revenue FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=1 AND bt.Name LIKE N'%$kwSalesPrefix%' AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY bt.Name ORDER BY Revenue DESC"
$report += (Dump (Run-Query $q6))
$report += ""

# 7. Monthly purchases (real purchases only, not internal transfers)
$report += "=== 7. MONTHLY PURCHASES (last 12 months) ==="
$q7 = "SELECT CONVERT(varchar(7), bu.Date,120) AS Month, SUM(bu.Total) AS PurchaseTotal FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=0 AND bt.bNoEntry=0 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY CONVERT(varchar(7), bu.Date,120) ORDER BY Month"
$report += (Dump (Run-Query $q7))
$report += ""

# 8. Slow-moving inventory (stock exists but no sales in 90 days)
$report += "=== 8. SLOW-MOVING INVENTORY (stock > 0, no sales in last 90 days) - top 30 ==="
$q8 = "SELECT TOP 30 mt.Name, mt.Qty FROM mt000 mt WHERE mt.Qty > 0.01 AND NOT EXISTS (SELECT 1 FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bi.MatGUID = mt.GUID AND bt.BillType=1 AND bu.Date >= DATEADD(day,-90,GETDATE())) ORDER BY mt.Qty DESC"
$report += (Dump (Run-Query $q8))
$report += ""

# 9. Gifts and promotions given away
$report += "=== 9. GIFTS AND PROMOTIONS GIVEN AWAY (last 12 months) ==="
$q9 = "SELECT COUNT(DISTINCT bu.GUID) AS GiftBills, SUM(bi.Qty*bi.Price) AS EstimatedListValue FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.Name = N'$kwGifts' AND bu.Date >= DATEADD(month,-12,GETDATE())"
$report += (Dump (Run-Query $q9))

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host ("Done. Report written to: " + $outFile)
Write-Host ("Total lines: " + $report.Count)
