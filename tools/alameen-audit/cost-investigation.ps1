# cost-investigation.ps1 (ASCII only in source)
# Read-only. Finds products where the system's "profit" is suspiciously close
# to 100% of revenue (profit ratio > 0.95), meaning cost is likely not recorded,
# then pulls sample sales and purchase lines for each so the accountant has
# concrete examples to check. No Arabic text is hard-coded in this file -- all
# product names come from live data via parameters, so there are no encoding
# issues when this file is downloaded.

$ErrorActionPreference = "Stop"
$cs = "Server=localhost;Database=AmnMwh26;Integrated Security=True;TrustServerCertificate=True"
$outDir = "$env:USERPROFILE\Desktop\AmnAudit"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = "$outDir\cost-investigation.txt"

function Run-Query($sql, $params) {
    $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandTimeout = 120
        $cmd.CommandText = $sql
        if ($params) {
            foreach ($key in $params.Keys) {
                [void]$cmd.Parameters.AddWithValue($key, $params[$key])
            }
        }
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
$report += "COST INVESTIGATION - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$report += "Finds products where recorded profit is suspiciously close to 100% of revenue."
$report += ""

# Step 1: find suspect products (last 12 months of real sales, BillType=1)
$q1 = "SELECT mt.GUID, mt.Name, mt.AvgPrice, mt.LastPrice, mt.MaxPrice, CASE WHEN mt.CostGuid IS NULL THEN 'NULL' ELSE 'SET' END AS CostGuidStatus, SUM(bi.Qty) AS TotalQty, SUM(bi.Qty*bi.Price) AS Revenue, SUM(bi.Netprofit) AS Profit, SUM(bi.UnitCostPrice*bi.Qty) AS RecordedCostTotal, CASE WHEN SUM(bi.Qty*bi.Price) > 0 THEN SUM(bi.Netprofit)/SUM(bi.Qty*bi.Price) ELSE NULL END AS ProfitRatio FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN mt000 mt ON mt.GUID=bi.MatGUID WHERE bt.BillType=1 AND bu.Date >= DATEADD(month,-12,GETDATE()) GROUP BY mt.GUID, mt.Name, mt.AvgPrice, mt.LastPrice, mt.MaxPrice, mt.CostGuid HAVING SUM(bi.Qty*bi.Price) > 1000 AND (SUM(bi.Netprofit)/SUM(bi.Qty*bi.Price)) > 0.95 ORDER BY Revenue DESC"
$suspects = Run-Query $q1 $null

$report += "=== SUSPECT PRODUCTS (profit ratio > 95% of revenue -- cost likely missing) ==="
$report += (Dump $suspects)
$report += ""

if ($suspects.Rows.Count -eq 0) {
    $report += "No suspect products found with the current threshold."
} else {
    foreach ($row in $suspects.Rows) {
        $matGuid = $row.GUID
        $name = $row.Name
        $report += "----------------------------------------------------------------"
        $report += ("PRODUCT: " + $name)
        $report += ("AvgPrice=" + $row.AvgPrice + "  LastPrice=" + $row.LastPrice + "  MaxPrice=" + $row.MaxPrice + "  CostGuid=" + $row.CostGuidStatus)
        $report += ""

        $report += "Recent SALES lines (last 5, any time):"
        $qSales = "SELECT TOP 5 bu.Date, bi.Qty, bi.Price, bi.UnitCostPrice, bi.Netprofit FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=1 AND bi.MatGUID=@mg ORDER BY bu.Date DESC"
        $salesRows = Run-Query $qSales @{ "@mg" = $matGuid }
        $report += (Dump $salesRows)
        $report += ""

        $report += "Purchase history (any time, up to 5 -- real purchases only):"
        $qPurch = "SELECT TOP 5 bu.Date, bi.Qty, bi.Price, bi.UnitCostPrice FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=0 AND bt.bNoEntry=0 AND bi.MatGUID=@mg ORDER BY bu.Date DESC"
        $purchRows = Run-Query $qPurch @{ "@mg" = $matGuid }
        if ($purchRows.Rows.Count -eq 0) {
            $report += "NONE FOUND - this product has never been purchased as a priced item."
        } else {
            $report += (Dump $purchRows)
        }
        $report += ""

        $report += "Production INPUT history (finished-goods-in, up to 5):"
        $qProd = "SELECT TOP 5 bu.Date, bi.Qty, bi.Price, bi.UnitCostPrice FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=4 AND bi.MatGUID=@mg ORDER BY bu.Date DESC"
        $prodRows = Run-Query $qProd @{ "@mg" = $matGuid }
        if ($prodRows.Rows.Count -eq 0) {
            $report += "NONE FOUND - no production-input records either."
        } else {
            $report += (Dump $prodRows)
        }
        $report += ""
    }
}

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host ("Done. Report written to: " + $outFile)
Write-Host ("Suspect products found: " + $suspects.Rows.Count)
