# check-user-activity.ps1 (ASCII only in source)
# Read-only. Shows what a specific user (matched by first/last name
# containing "Rahman") changed in the last 3 days: invoices and cash
# vouchers. Edit $searchWord below to check a different user.

$ErrorActionPreference = "Stop"
$cs = "Server=localhost;Database=AmnMwh26;Integrated Security=True;TrustServerCertificate=True"
$outDir = "$env:USERPROFILE\Desktop\AmnAudit"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = "$outDir\user-activity.txt"

# Arabic keyword built from Unicode code points (avoids file-encoding issues).
$searchWord = -join @([char]0x0631,[char]0x062D,[char]0x0645,[char]0x0646)  # "Rahman"

function Run-Query($sql, $kw) {
    $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandTimeout = 60
        $cmd.CommandText = $sql
        [void]$cmd.Parameters.AddWithValue("@kw", $kw)
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
$report += "USER ACTIVITY CHECK - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$report += "Matching users whose first/last name contains the search word."
$report += ""

$report += "=== Matching users ==="
$q0 = "SELECT LoginName, FirstName, LastName, bAdmin, IsInactive FROM us000 WHERE FirstName LIKE N'%' + @kw + N'%' OR LastName LIKE N'%' + @kw + N'%'"
$report += (Dump (Run-Query $q0 $searchWord))
$report += ""

$report += "=== Invoices he last-updated (last 3 days) ==="
$q1 = "SELECT bu.Number, bt.Name AS BillType, bu.Date, bu.LastUpdateDate, bu.Total FROM bu000 bu LEFT JOIN bt000 bt ON bt.GUID=bu.TypeGUID JOIN us000 u ON u.GUID=bu.LastUpdateUserGUID WHERE (u.FirstName LIKE N'%' + @kw + N'%' OR u.LastName LIKE N'%' + @kw + N'%') AND bu.LastUpdateDate >= DATEADD(day,-3,GETDATE()) ORDER BY bu.LastUpdateDate DESC"
$report += (Dump (Run-Query $q1 $searchWord))
$report += ""

$report += "=== Cash vouchers he created (last 3 days) ==="
$q2 = "SELECT ce.Number, ce.Date, ce.Debit, ce.Credit, ce.Notes FROM ce000 ce JOIN us000 u ON u.GUID=ce.CreateUserGuid WHERE (u.FirstName LIKE N'%' + @kw + N'%' OR u.LastName LIKE N'%' + @kw + N'%') AND ce.Date >= DATEADD(day,-3,GETDATE()) ORDER BY ce.Date DESC"
$report += (Dump (Run-Query $q2 $searchWord))

$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host ("Done. Report written to: " + $outFile)
Write-Host ("Total lines: " + $report.Count)
