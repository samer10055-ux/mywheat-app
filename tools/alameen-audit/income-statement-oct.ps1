# income-statement-oct.ps1 (ASCII only in source)
# Read-only. Builds the data needed for an October income statement:
# Net Sales, recorded COGS, Purchases, and top general-ledger account
# activity (to let the accountant classify real operating expenses).
# No Arabic text is hard-coded; dates are numeric, and all names come
# from live data at runtime.

$ErrorActionPreference = "Stop"
$cs = "Server=localhost;Database=AmnMwh26;Integrated Security=True;TrustServerCertificate=True"
$outDir = "$env:USERPROFILE\Desktop\AmnAudit"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = "$outDir\income-statement-oct.txt"

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
$report += "OCTOBER 2026 INCOME STATEMENT DATA - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$report += "Period: 2026-10-01 to 2026-10-31"
$report += ""

$report += "=== 1. Net Sales (October) ==="
$q = "SELECT SUM(CASE WHEN bt.BillType=1 THEN bu.Total ELSE 0 END) AS GrossSales, SUM(CASE WHEN bt.BillType=3 THEN bu.Total ELSE 0 END) AS Returns, SUM(CASE WHEN bt.BillType=1 THEN bu.Total ELSE 0 END) - SUM(CASE WHEN bt.BillType=3 THEN bu.Total ELSE 0 END) AS NetSales FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType IN (1,3) AND bu.Date >= '2026-10-01' AND bu.Date < '2026-11-01'"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 2. Recorded COGS (October) -- from bi.UnitCostPrice, known to be incomplete for some product lines ==="
$q = "SELECT SUM(bi.UnitCostPrice*bi.Qty) AS RecordedCOGS FROM bi000 bi JOIN bu000 bu ON bi.ParentGUID=bu.GUID JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=1 AND bu.Date >= '2026-10-01' AND bu.Date < '2026-11-01'"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 3. Purchases (October) -- cash-basis cross-check, not the same as COGS ==="
$q = "SELECT SUM(bu.Total) AS PurchasesTotal FROM bu000 bu JOIN bt000 bt ON bt.GUID=bu.TypeGUID WHERE bt.BillType=0 AND bt.bNoEntry=0 AND bu.Date >= '2026-10-01' AND bu.Date < '2026-11-01'"
$report += (Dump (Run-Query $q))
$report += ""

$report += "=== 4. Top 40 general-ledger accounts by activity (ax000) in October ==="
$report += "Raw Debit/Credit as entered -- please classify which are real operating expenses vs other movements."
$q = "SELECT ac.Name, ac.Type AS AccountType, SUM(CASE WHEN ax.Value >= 0 THEN ax.Value ELSE 0 END) AS TotalDebitLike, SUM(CASE WHEN ax.Value < 0 THEN -ax.Value ELSE 0 END) AS TotalCreditLike, SUM(ax.Value) AS NetValue, COUNT(*) AS EntryCount FROM ax000 ax JOIN ac000 ac ON ac.GUID = ax.AccGUID WHERE ax.Date >= '2026-10-01' AND ax.Date < '2026-11-01' GROUP BY ac.Name, ac.Type ORDER BY (ABS(SUM(ax.Value))) DESC OFFSET 0 ROWS FETCH NEXT 40 ROWS ONLY"
$report += (Dump (Run-Query $q))

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host ("Done. Report written to: " + $outFile)
Write-Host ("Total lines: " + $report.Count)
