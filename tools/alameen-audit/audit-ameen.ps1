# audit-ameen.ps1 (ASCII only - avoids encoding issues)
# Daily read-only audit for Al-Ameen (AmnMwh26) on SQL Server.
# Runs SELECT queries only -- never INSERT/UPDATE/DELETE. Safe to run repeatedly.
# Output: HTML report on Desktop\AmnAudit\ + a popup if any issues are found.

$ErrorActionPreference = "Stop"
$server   = "localhost"
$database = "AmnMwh26"
$cs = "Server=$server;Database=$database;Integrated Security=True;TrustServerCertificate=True"

$reportDir = Join-Path $env:USERPROFILE "Desktop\AmnAudit"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$reportFile = Join-Path $reportDir ("audit_" + $stamp + ".html")
$latestFile = Join-Path $reportDir "audit_latest.html"

function Run-Query($connString, $sql) {
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 60
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $table = New-Object System.Data.DataTable
        [void]$adapter.Fill($table)
        return ,$table
    } finally { $conn.Close() }
}

function Table-ToHtml($dt, $emptyMsg) {
    if ($dt.Rows.Count -eq 0) { return "<p class='ok'>" + $emptyMsg + "</p>" }
    $html = "<table><tr>"
    foreach ($c in $dt.Columns) { $html += "<th>" + $c.ColumnName + "</th>" }
    $html += "</tr>"
    foreach ($r in $dt.Rows) {
        $html += "<tr>"
        foreach ($c in $dt.Columns) { $html += "<td>" + $r[$c.ColumnName] + "</td>" }
        $html += "</tr>"
    }
    $html += "</table>"
    return $html
}

$totalIssues = 0
$sections = New-Object System.Collections.ArrayList

try {

# ===== 1. Financial checks =====
$q1 = "SELECT bu.Number, bu.Date, u.LoginName AS CreatedBy, bu.Total FROM bu000 bu LEFT JOIN us000 u ON u.GUID = bu.CreateUserGUID WHERE bu.IsPosted = 0 AND bu.Date < DATEADD(day,-3,GETDATE()) ORDER BY bu.Date"
$r1 = Run-Query $cs $q1
$totalIssues += $r1.Rows.Count
[void]$sections.Add("<h2>1. Unposted invoices older than 3 days</h2>" + (Table-ToHtml $r1 "No overdue unposted invoices."))

# Build Arabic exclusion keywords from Unicode code points to avoid file-encoding issues.
# These mean: transfer / movement / inventory-count document types, which legitimately
# have zero total value and are not an error.
$kwTransfer = -join @([char]0x0645,[char]0x0646,[char]0x0627,[char]0x0642,[char]0x0644,[char]0x0629)   # transfer (manaqala)
$kwMove     = -join @([char]0x062A,[char]0x062D,[char]0x0648,[char]0x064A,[char]0x0644)                # movement (tahweel)
$kwCount    = -join @([char]0x062C,[char]0x0631,[char]0x062F)                                          # inventory count (jard)
$kwLoad     = -join @([char]0x062A,[char]0x062D,[char]0x0645,[char]0x064A,[char]0x0644)                # vehicle loading (tahmeel)
$kwCollect  = -join @([char]0x062A,[char]0x062D,[char]0x0635,[char]0x064A,[char]0x0644)                # vehicle collection (tahseel)

$q2 = "SELECT bu.Number, bu.Date, bt.Name AS BillType, u.LoginName AS CreatedBy, bu.Total FROM bu000 bu LEFT JOIN us000 u ON u.GUID = bu.CreateUserGUID LEFT JOIN bt000 bt ON bt.GUID = bu.TypeGUID WHERE bu.Total <= 0 AND EXISTS (SELECT 1 FROM bi000 bi WHERE bi.ParentGUID = bu.GUID) AND (bt.Name IS NULL OR (bt.Name NOT LIKE N'%" + $kwTransfer + "%' AND bt.Name NOT LIKE N'%" + $kwMove + "%' AND bt.Name NOT LIKE N'%" + $kwCount + "%' AND bt.Name NOT LIKE N'%" + $kwLoad + "%' AND bt.Name NOT LIKE N'%" + $kwCollect + "%')) ORDER BY bu.Date DESC"
$r2 = Run-Query $cs $q2
$totalIssues += $r2.Rows.Count
[void]$sections.Add("<h2>2. Invoices with zero/negative total despite having items</h2>" + (Table-ToHtml $r2 "No invoices with abnormal totals."))

$q3 = "SELECT ce.Number, ce.Date, u.LoginName AS CreatedBy, ce.Debit, ce.Credit FROM ce000 ce LEFT JOIN us000 u ON u.GUID = ce.CreateUserGuid WHERE ce.Debit < 0 OR ce.Credit < 0 ORDER BY ce.Date DESC"
$r3 = Run-Query $cs $q3
$totalIssues += $r3.Rows.Count
[void]$sections.Add("<h2>3. Cash receipt/payment vouchers with negative values</h2>" + (Table-ToHtml $r3 "No vouchers with negative values."))

# ===== 2. Inventory checks =====
# Qty is a float column; tiny values like -1E-13 are rounding noise, not real negative
# stock. Only flag a meaningful shortage (more than 0.01 units negative).
$q4 = "SELECT mt.Name, mt.Code, ms.Qty FROM ms000 ms JOIN mt000 mt ON mt.GUID = ms.MatGUID WHERE ms.Qty < -0.01 ORDER BY ms.Qty ASC"
$r4 = Run-Query $cs $q4
$totalIssues += $r4.Rows.Count
[void]$sections.Add("<h2>4. Negative stock balance (per store)</h2>" + (Table-ToHtml $r4 "No negative per-store stock balances."))

$q5 = "SELECT mt.Name, mt.Code, mt.Qty FROM mt000 mt WHERE mt.Qty < -0.01 ORDER BY mt.Qty ASC"
$r5 = Run-Query $cs $q5
$totalIssues += $r5.Rows.Count
[void]$sections.Add("<h2>5. Negative total stock balance</h2>" + (Table-ToHtml $r5 "No negative total stock balances."))

$q6 = "SELECT mt.Name, mt.Code, mt.LastPrice, mt.MaxPrice FROM mt000 mt WHERE mt.LastPrice < 0 OR mt.MaxPrice < 0 OR (mt.MaxPrice > 0 AND mt.LastPrice > mt.MaxPrice)"
$r6 = Run-Query $cs $q6
$totalIssues += $r6.Rows.Count
[void]$sections.Add("<h2>6. Abnormal material prices (negative or above max)</h2>" + (Table-ToHtml $r6 "No abnormal prices."))

# ===== 3. Suspicious user activity =====
$q7 = "SELECT bu.Number, bu.Date, cu.LoginName AS CreatedBy, lu.LoginName AS LastUpdatedBy, bu.LastUpdateDate FROM bu000 bu LEFT JOIN us000 cu ON cu.GUID = bu.CreateUserGUID LEFT JOIN us000 lu ON lu.GUID = bu.LastUpdateUserGUID WHERE bu.CreateUserGUID IS NOT NULL AND bu.LastUpdateUserGUID IS NOT NULL AND bu.CreateUserGUID <> bu.LastUpdateUserGUID AND bu.LastUpdateDate > DATEADD(day,-1,GETDATE()) ORDER BY bu.LastUpdateDate DESC"
$r7 = Run-Query $cs $q7
$totalIssues += $r7.Rows.Count
[void]$sections.Add("<h2>7. Invoices modified by a user other than the creator (last day)</h2>" + (Table-ToHtml $r7 "No cross-user modifications found."))

$q8 = "SELECT bu.Number, bu.CreateDate, u.LoginName FROM bu000 bu LEFT JOIN us000 u ON u.GUID = bu.CreateUserGUID WHERE bu.CreateDate > DATEADD(day,-1,GETDATE()) AND (DATEPART(hour, bu.CreateDate) < 7 OR DATEPART(hour, bu.CreateDate) > 22) ORDER BY bu.CreateDate DESC"
$r8 = Run-Query $cs $q8
$totalIssues += $r8.Rows.Count
[void]$sections.Add("<h2>8. Invoices created outside work hours (before 7am or after 10pm)</h2>" + (Table-ToHtml $r8 "No invoices outside work hours."))

$q9 = "SELECT LoginName, ModifyDate FROM UsPasHistory000 WHERE ModifyDate > DATEADD(day,-1,GETDATE()) ORDER BY ModifyDate DESC"
$r9 = Run-Query $cs $q9
$totalIssues += $r9.Rows.Count
[void]$sections.Add("<h2>9. Password changes in the last day</h2>" + (Table-ToHtml $r9 "No password changes."))

$q10 = "SELECT LoginName, FirstName, LastName FROM us000 WHERE bAdmin = 1 AND IsInactive = 0"
$r10 = Run-Query $cs $q10
[void]$sections.Add("<h2>10. Users with admin privilege (for review)</h2>" + (Table-ToHtml $r10 "No admin users found."))

# ===== 4. System errors =====
$q11 = "SELECT TOP 50 ID, Time, Notes FROM DBLog WHERE Time > DATEADD(day,-1,GETDATE()) ORDER BY Time DESC"
$r11 = Run-Query $cs $q11
[void]$sections.Add("<h2>11. System events (DBLog) in the last day (latest 50)</h2>" + (Table-ToHtml $r11 "No system events logged."))

$q12 = "SELECT StartLogTime, UserGUID, Computer, CloseReason FROM MaintenanceLog000 WHERE EndLogTime IS NULL AND StartLogTime > DATEADD(day,-2,GETDATE())"
$r12 = Run-Query $cs $q12
$totalIssues += $r12.Rows.Count
[void]$sections.Add("<h2>12. Incomplete maintenance runs (last 2 days)</h2>" + (Table-ToHtml $r12 "No incomplete maintenance runs."))

} catch {
    [void]$sections.Add("<h2 style='color:red'>Error during audit</h2><pre>" + $_.Exception.Message + "</pre>")
    $totalIssues += 1
}

$statusColor = "#27ae60"
$statusText  = "No issues found today"
if ($totalIssues -gt 0) {
    $statusColor = "#c0392b"
    $statusText  = "ALERT: " + $totalIssues + " item(s) need review"
}

$sectionsHtml = [string]::Join("`n", $sections.ToArray())

$html = "<html><head><meta charset='utf-8'>" +
"<style>" +
"body { font-family: Tahoma, Arial; margin: 20px; background:#f7f7f7; }" +
"h1 { color:#222; }" +
"h2 { color:#444; border-bottom:1px solid #ccc; padding-bottom:4px; margin-top:28px; }" +
"table { border-collapse: collapse; width:100%; margin-top:8px; background:#fff; }" +
"th, td { border:1px solid #ddd; padding:6px 10px; font-size:13px; text-align:left; }" +
"th { background:#eee; }" +
".ok { color:#27ae60; }" +
".status { font-size:18px; font-weight:bold; padding:12px; border-radius:6px; color:#fff; background:" + $statusColor + "; display:inline-block; }" +
"</style></head><body>" +
"<h1>Al-Ameen Audit Report -- " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + "</h1>" +
"<div class='status'>" + $statusText + "</div>" +
$sectionsHtml +
"</body></html>"

$html | Out-File -FilePath $reportFile -Encoding UTF8
$html | Out-File -FilePath $latestFile -Encoding UTF8

if ($totalIssues -gt 0) {
    try {
        Add-Type -AssemblyName PresentationFramework
        $msg = "Al-Ameen Audit: " + $totalIssues + " item(s) need review.`nReport: " + $latestFile
        [System.Windows.MessageBox]::Show($msg, "Al-Ameen Audit Alert", "OK", "Warning") | Out-Null
    } catch { }
}

Write-Host ("Audit complete. Issues found: " + $totalIssues)
Write-Host ("Report: " + $reportFile)
