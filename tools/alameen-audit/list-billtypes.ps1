# list-billtypes.ps1 (ASCII only)
# Read-only: dumps all document/bill types (bt000) so we can build an accurate
# business analysis later, instead of guessing. Safe, no data changes.

$ErrorActionPreference = "Stop"
$cs = "Server=localhost;Database=AmnMwh26;Integrated Security=True;TrustServerCertificate=True"
$outFile = "$env:USERPROFILE\Desktop\AmnAudit\billtypes.txt"

$conn = New-Object System.Data.SqlClient.SqlConnection($cs)
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT bt.Name, bt.BillGroup, bt.BillType, bt.bIsInput, bt.bIsOutput, bt.bPOSBill, bt.bCashBill, bt.bNoEntry, (SELECT COUNT(*) FROM bu000 bu WHERE bu.TypeGUID = bt.GUID) AS UsedCount FROM bt000 bt ORDER BY UsedCount DESC"
$ad = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
$dt = New-Object System.Data.DataTable
[void]$ad.Fill($dt)
$conn.Close()

$lines = @()
foreach ($r in $dt.Rows) {
    $lines += ($r.Name + "`t" + $r.BillGroup + "`t" + $r.BillType + "`t" + $r.bIsInput + "`t" + $r.bIsOutput + "`t" + $r.bPOSBill + "`t" + $r.bCashBill + "`t" + $r.bNoEntry + "`t" + $r.UsedCount)
}
$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host ("Done. " + $dt.Rows.Count + " bill types written to: " + $outFile)
