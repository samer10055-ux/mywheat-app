# audit-ameen.ps1
# Daily read-only audit for Al-Ameen (AmnMwh26) on SQL Server.
# Runs SELECT queries only -- never INSERT/UPDATE/DELETE. Safe to run repeatedly.
# Output: HTML report on Desktop\AmnAudit\ + a popup if the task runs interactively.

$ErrorActionPreference = "Stop"
$server   = "localhost"
$database = "AmnMwh26"
$cs = "Server=$server;Database=$database;Integrated Security=True;TrustServerCertificate=True"

$reportDir = Join-Path $env:USERPROFILE "Desktop\AmnAudit"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$reportFile = Join-Path $reportDir "audit_$stamp.html"
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
    if ($dt.Rows.Count -eq 0) { return "<p class='ok'>$emptyMsg</p>" }
    $html = "<table><tr>"
    foreach ($c in $dt.Columns) { $html += "<th>$($c.ColumnName)</th>" }
    $html += "</tr>"
    foreach ($r in $dt.Rows) {
        $html += "<tr>"
        foreach ($c in $dt.Columns) { $html += "<td>$($r[$c.ColumnName])</td>" }
        $html += "</tr>"
    }
    $html += "</table>"
    return $html
}

$totalIssues = 0
$sections = @()

try {

# ===== 1. Financial checks =====
$q1 = @"
SELECT bu.Number, bu.Date, u.LoginName AS CreatedBy, bu.Total
FROM bu000 bu LEFT JOIN us000 u ON u.GUID = bu.CreateUserGUID
WHERE bu.IsPosted = 0 AND bu.Date < DATEADD(day,-3,GETDATE())
ORDER BY bu.Date
"@
$r1 = Run-Query $cs $q1
$totalIssues += $r1.Rows.Count
$sections += "<h2>1. فواتير غير مرحّلة منذ أكثر من 3 أيام</h2>" + (Table-ToHtml $r1 "لا توجد فواتير غير مرحّلة متأخرة.")

$q2 = @"
SELECT bu.Number, bu.Date, u.LoginName AS CreatedBy, bu.Total
FROM bu000 bu LEFT JOIN us000 u ON u.GUID = bu.CreateUserGUID
WHERE bu.Total <= 0 AND EXISTS (SELECT 1 FROM bi000 bi WHERE bi.ParentGUID = bu.GUID)
ORDER BY bu.Date DESC
"@
$r2 = Run-Query $cs $q2
$totalIssues += $r2.Rows.Count
$sections += "<h2>2. فواتير بإجمالي صفر أو سالب رغم وجود بنود</h2>" + (Table-ToHtml $r2 "لا توجد فواتير بإجمالي شاذ.")

$q3 = @"
SELECT ce.Number, ce.Date, u.LoginName AS CreatedBy, ce.Debit, ce.Credit
FROM ce000 ce LEFT JOIN us000 u ON u.GUID = ce.CreateUserGuid
WHERE ce.Debit < 0 OR ce.Credit < 0
ORDER BY ce.Date DESC
"@
$r3 = Run-Query $cs $q3
$totalIssues += $r3.Rows.Count
$sections += "<h2>3. سندات قبض/صرف بقيم سالبة</h2>" + (Table-ToHtml $r3 "لا توجد سندات بقيم سالبة.")

# ===== 2. Inventory checks =====
$q4 = @"
SELECT mt.Name, mt.Code, ms.Qty
FROM ms000 ms JOIN mt000 mt ON mt.GUID = ms.MatGUID
WHERE ms.Qty < 0
ORDER BY ms.Qty ASC
"@
$r4 = Run-Query $cs $q4
$totalIssues += $r4.Rows.Count
$sections += "<h2>4. رصيد مخزون سالب (حسب المستودع)</h2>" + (Table-ToHtml $r4 "لا يوجد رصيد مخزون سالب.")

$q5 = @"
SELECT mt.Name, mt.Code, mt.Qty
FROM mt000 mt
WHERE mt.Qty < 0
ORDER BY mt.Qty ASC
"@
$r5 = Run-Query $cs $q5
$totalIssues += $r5.Rows.Count
$sections += "<h2>5. رصيد مخزون إجمالي سالب</h2>" + (Table-ToHtml $r5 "لا يوجد رصيد إجمالي سالب.")

$q6 = @"
SELECT mt.Name, mt.Code, mt.LastPrice, mt.MaxPrice
FROM mt000 mt
WHERE mt.LastPrice < 0 OR mt.MaxPrice < 0 OR (mt.MaxPrice > 0 AND mt.LastPrice > mt.MaxPrice)
"@
$r6 = Run-Query $cs $q6
$totalIssues += $r6.Rows.Count
$sections += "<h2>6. أسعار مواد شاذة (سالبة أو تتجاوز الحد الأقصى)</h2>" + (Table-ToHtml $r6 "لا توجد أسعار شاذة.")

# ===== 3. Suspicious user activity =====
$q7 = @"
SELECT bu.Number, bu.Date, cu.LoginName AS CreatedBy, lu.LoginName AS LastUpdatedBy, bu.LastUpdateDate
FROM bu000 bu
LEFT JOIN us000 cu ON cu.GUID = bu.CreateUserGUID
LEFT JOIN us000 lu ON lu.GUID = bu.LastUpdateUserGUID
WHERE bu.CreateUserGUID IS NOT NULL AND bu.LastUpdateUserGUID IS NOT NULL
  AND bu.CreateUserGUID <> bu.LastUpdateUserGUID
  AND bu.LastUpdateDate > DATEADD(day,-1,GETDATE())
ORDER BY bu.LastUpdateDate DESC
"@
$r7 = Run-Query $cs $q7
$totalIssues += $r7.Rows.Count
$sections += "<h2>7. فواتير عدّلها مستخدم غير من أنشأها (آخر يوم)</h2>" + (Table-ToHtml $r7 "لا توجد تعديلات من مستخدم آخر.")

$q8 = @"
SELECT bu.Number, bu.CreateDate, u.LoginName
FROM bu000 bu LEFT JOIN us000 u ON u.GUID = bu.CreateUserGUID
WHERE bu.CreateDate > DATEADD(day,-1,GETDATE())
  AND (DATEPART(hour, bu.CreateDate) < 7 OR DATEPART(hour, bu.CreateDate) > 22)
ORDER BY bu.CreateDate DESC
"@
$r8 = Run-Query $cs $q8
$totalIssues += $r8.Rows.Count
$sections += "<h2>8. فواتير أُنشئت خارج دوام العمل (قبل 7ص أو بعد 10م)</h2>" + (Table-ToHtml $r8 "لا توجد فواتير خارج الدوام.")

$q9 = @"
SELECT LoginName, ModifyDate
FROM UsPasHistory000
WHERE ModifyDate > DATEADD(day,-1,GETDATE())
ORDER BY ModifyDate DESC
"@
$r9 = Run-Query $cs $q9
$totalIssues += $r9.Rows.Count
$sections += "<h2>9. تغييرات كلمة مرور في آخر يوم</h2>" + (Table-ToHtml $r9 "لا توجد تغييرات كلمة مرور.")

$q10 = @"
SELECT LoginName, FirstName, LastName
FROM us000
WHERE bAdmin = 1 AND IsInactive = 0
"@
$r10 = Run-Query $cs $q10
$sections += "<h2>10. المستخدمون بصلاحية مدير (للمراجعة)</h2>" + (Table-ToHtml $r10 "لا يوجد مستخدمون بصلاحية مدير.")

# ===== 4. System errors =====
$q11 = @"
SELECT TOP 50 ID, Time, Notes
FROM DBLog
WHERE Time > DATEADD(day,-1,GETDATE())
ORDER BY Time DESC
"@
$r11 = Run-Query $cs $q11
$sections += "<h2>11. أحداث النظام (DBLog) آخر يوم (آخر 50)</h2>" + (Table-ToHtml $r11 "لا توجد أحداث نظام مسجلة.")

$q12 = @"
SELECT StartLogTime, UserGUID, Computer, CloseReason
FROM MaintenanceLog000
WHERE EndLogTime IS NULL AND StartLogTime > DATEADD(day,-2,GETDATE())
"@
$r12 = Run-Query $cs $q12
$totalIssues += $r12.Rows.Count
$sections += "<h2>12. عمليات صيانة لم تكتمل (آخر يومين)</h2>" + (Table-ToHtml $r12 "لا توجد عمليات صيانة ناقصة.")

} catch {
    $sections += "<h2 style='color:red'>خطأ أثناء التدقيق</h2><pre>$($_.Exception.Message)</pre>"
    $totalIssues += 1
}

$statusColor = if ($totalIssues -gt 0) { "#c0392b" } else { "#27ae60" }
$statusText  = if ($totalIssues -gt 0) { "تنبيه: وُجد $totalIssues بنداً يستحق المراجعة" } else { "لا توجد أخطاء اليوم" }

$html = @"
<html dir='rtl'><head><meta charset='utf-8'>
<style>
body { font-family: Tahoma, Arial; margin: 20px; background:#f7f7f7; }
h1 { color:#222; }
h2 { color:#444; border-bottom:1px solid #ccc; padding-bottom:4px; margin-top:28px; }
table { border-collapse: collapse; width:100%; margin-top:8px; background:#fff; }
th, td { border:1px solid #ddd; padding:6px 10px; font-size:13px; text-align:right; }
th { background:#eee; }
.ok { color:#27ae60; }
.status { font-size:18px; font-weight:bold; padding:12px; border-radius:6px; color:#fff; background:$statusColor; display:inline-block; }
</style></head><body>
<h1>تقرير تدقيق الأمين -- $(Get-Date -Format 'yyyy-MM-dd HH:mm')</h1>
<div class='status'>$statusText</div>
$($sections -join "`n")
</body></html>
"@

$html | Out-File -FilePath $reportFile -Encoding UTF8
$html | Out-File -FilePath $latestFile -Encoding UTF8

if ($totalIssues -gt 0) {
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("تدقيق الأمين: وُجد $totalIssues بنداً يستحق المراجعة.`nافتح التقرير: $latestFile", "تنبيه تدقيق الأمين", "OK", "Warning") | Out-Null
    } catch { }
}

Write-Host "Audit complete. Issues found: $totalIssues"
Write-Host "Report: $reportFile"
