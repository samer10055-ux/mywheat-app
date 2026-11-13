# department-report.ps1 (ASCII only in source)
# Read-only. Builds a deeper analysis split by department: Finance, Sales,
# Cost, Marketing, Warehouse. No data is changed. No Arabic text is hard-coded
# in this file -- classification uses bt000.BillType / cu000.Type numeric
# codes, not name matching, so there are no encoding issues.

$ErrorActionPreference = "Stop"
$cs = "Server=localhost;Database=AmnMwh26;Integrated Security=True;TrustServerCertificate=True"
$outDir = "$env:USERPROFILE\Desktop\AmnAudit"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = "$outDir\department-report.txt"

function Run-Query($sql) {
    $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandTimeout = 180
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

$report = @()
$report += "DEPARTMENT REPORT - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$report += ""

# ===================== FINANCE =====================
$report += "########## 1. FINANCE (CFO) ##########"
$report += ""
$report += "=== 1a. Monthly cash movement (receipts/payments, ce000) ==="
$q = "SELECT CONVERT(varchar(7), ce.Date,120) AS Month, SUM(ce.Debit) AS TotalDebit, SUM(ce.Credit) AS TotalCredit, SUM(ce.Debit-ce.Credit) AS NetMovement FROM ce000 ce WHERE ce.Date >= DATEADD(month,-12,GETDATE()) GROUP BY CONVERT(varchar(7), ce.Date,120) ORDER BY Month"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 1b. Checks (ch000) summary by direction and state ==="
$q = "SELECT ch.Dir, ch.State, COUNT(*) AS Cnt, SUM(ch.Val) AS TotalVal FROM ch000 ch GROUP BY ch.Dir, ch.State ORDER BY ch.Dir, ch.State"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 1c. Overdue checks (DueDate in the past) ==="
$q = "SELECT ch.Dir, ch.Num, ch.DueDate, ch.Val, ch.State FROM ch000 ch WHERE ch.DueDate < GETDATE() ORDER BY ch.DueDate"
$report += (Dump (Run-Query $q))
$report += ""

# ===================== SALES =====================
$report += "########## 2. SALES ##########"
$report += ""
$report += "=== 2a. Top 15 customers: first half vs second half of the last 12 months ==="
$q = "SELECT cu.CustomerName, SUM(CASE WHEN bu.Date < DATEADD(month,-6,GETDATE()) THEN bu.Total ELSE 0 END) AS FirstHalf, SUM(CASE WHEN bu.Date >= DATEADD(month,-6,GETDATE()) THEN bu.Total ELSE 0 END) AS SecondHalf FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN cu000 cu ON cu.GUID=bu.CustGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY cu.CustomerName ORDER BY (FirstHalf+SecondHalf) DESC OFFSET 0 ROWS FETCH NEXT 15 ROWS ONLY"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 2b. New customers (first invoice in last 90 days) ==="
$q = "SELECT cu.CustomerName, MIN(bu.Date) AS FirstInvoiceDate, COUNT(*) AS InvoicesSoFar, SUM(bu.Total) AS RevenueSoFar FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN cu000 cu ON cu.GUID=bu.CustGUID WHERE bt.BillType=1 GROUP BY cu.CustomerName HAVING MIN(bu.Date) >= DATEADD(day,-90,GETDATE()) ORDER BY FirstInvoiceDate DESC"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 2c. Customers with NO sales in last 90 days but had sales before (at-risk/churn) ==="
$q = "SELECT cu.CustomerName, MAX(bu.Date) AS LastInvoiceDate, SUM(bu.Total) AS LifetimeRevenue FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN cu000 cu ON cu.GUID=bu.CustGUID WHERE bt.BillType=1 GROUP BY cu.CustomerName HAVING MAX(bu.Date) < DATEADD(day,-90,GETDATE()) AND MAX(bu.Date) >= DATEADD(month,-12,GETDATE()) ORDER BY LifetimeRevenue DESC"
$report += (Dump (Run-Query $q))
$report += ""

# ===================== COST =====================
$report += "########## 3. COST ##########"
$report += ""
$report += "=== 3a. TRUE margin for top 40 products (Revenue minus recorded UnitCostPrice, ignoring the broken Netprofit field) ==="
$q = "SELECT TOP 40 mt.Name, SUM(bi.Qty) AS TotalQty, SUM(bi.Qty*bi.Price) AS Revenue, SUM(bi.UnitCostPrice*bi.Qty) AS RecordedCost, SUM(bi.Qty*bi.Price) - SUM(bi.UnitCostPrice*bi.Qty) AS TrueMargin, CASE WHEN SUM(bi.Qty*bi.Price) > 0 THEN (SUM(bi.Qty*bi.Price) - SUM(bi.UnitCostPrice*bi.Qty)) / SUM(bi.Qty*bi.Price) ELSE NULL END AS TrueMarginRatio FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN mt000 mt ON mt.GUID=bi.MatGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY mt.Name ORDER BY Revenue DESC"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 3b. Products with ZERO recorded cost anywhere (true cost gap, top 30 by revenue) ==="
$q = "SELECT TOP 30 mt.Name, SUM(bi.Qty) AS TotalQty, SUM(bi.Qty*bi.Price) AS Revenue, SUM(bi.UnitCostPrice*bi.Qty) AS RecordedCost FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN mt000 mt ON mt.GUID=bi.MatGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY mt.Name HAVING SUM(bi.Qty*bi.Price) > 500 AND SUM(bi.UnitCostPrice*bi.Qty) = 0 ORDER BY Revenue DESC"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 3c. Monthly purchase price trend for the 10 most purchased materials ==="
$q = "SELECT mt.Name, CONVERT(varchar(7), bu.Date,120) AS Month, AVG(bi.Price) AS AvgPurchasePrice, SUM(bi.Qty) AS TotalQty FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN mt000 mt ON mt.GUID=bi.MatGUID WHERE bt.BillType=0 AND bt.bNoEntry=0 AND bu.Date >= DATEADD(month,-12,GETDATE()) AND mt.GUID IN (SELECT TOP 10 bi2.MatGUID FROM bi000 bi2 JOIN bu000 bu2 ON bi2.ParentGUID=bu2.GUID JOIN bt000 bt2 ON bt2.GUID=bu2.TypeGUID WHERE bt2.BillType=0 AND bt2.bNoEntry=0 GROUP BY bi2.MatGUID ORDER BY SUM(bi2.Qty) DESC) GROUP BY mt.Name, CONVERT(varchar(7), bu.Date,120) ORDER BY mt.Name, Month"
$report += (Dump (Run-Query $q))
$report += ""

# ===================== MARKETING =====================
$report += "########## 4. MARKETING ##########"
$report += ""
$report += "=== 4a. Revenue by customer segment (cu000.Type code) ==="
$q = "SELECT cu.Type, COUNT(DISTINCT cu.GUID) AS CustomerCount, SUM(bu.Total) AS Revenue FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN cu000 cu ON cu.GUID=bu.CustGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY cu.Type ORDER BY Revenue DESC"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 4b. Top 15 products given away as gifts/promotions (by quantity) ==="
$q = "SELECT TOP 15 mt.Name, SUM(bi.Qty) AS TotalQtyGiven, SUM(bi.Qty*bi.Price) AS EstimatedListValue, COUNT(DISTINCT bu.GUID) AS BillCount FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN mt000 mt ON mt.GUID=bi.MatGUID WHERE bt.BillType=5 AND bt.bNoEntry=0 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY mt.Name ORDER BY TotalQtyGiven DESC"
$report += (Dump (Run-Query $q))
$report += ""

# ===================== WAREHOUSE =====================
$report += "########## 5. WAREHOUSE ##########"
$report += ""
$report += "=== 5a. TRUE dead stock: current stock > 0, not used in ANY sale or production output in 90 days (top 30) ==="
$q = "SELECT TOP 30 mt.Name, mt.Qty FROM mt000 mt WHERE mt.Qty > 0.01 AND NOT EXISTS (SELECT 1 FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bi.MatGUID = mt.GUID AND bt.BillType IN (1,5) AND bu.Date >= DATEADD(day,-90,GETDATE())) ORDER BY mt.Qty DESC"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 5b. Negative stock balances (meaningful, more than 0.01 units) ==="
$q = "SELECT mt.Name, mt.Qty FROM mt000 mt WHERE mt.Qty < -0.01 ORDER BY mt.Qty ASC"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 5c. Top 20 highest-value current inventory (Qty * AvgPrice) ==="
$q = "SELECT TOP 20 mt.Name, mt.Qty, mt.AvgPrice, (mt.Qty*mt.AvgPrice) AS InventoryValue FROM mt000 mt WHERE mt.Qty > 0 ORDER BY InventoryValue DESC"
$report += (Dump (Run-Query $q))

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host ("Done. Report written to: " + $outFile)
Write-Host ("Total lines: " + $report.Count)
