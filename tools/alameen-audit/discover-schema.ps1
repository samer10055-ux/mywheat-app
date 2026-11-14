# discover-schema.ps1
# سكربت للقراءة فقط: يستخرج أسماء قواعد البيانات والجداول والأعمدة من SQL Server.
# لا يعدّل أي بيانات. لا يحتاج تثبيت شيء (PowerShell + .NET موجودان في Windows).
# الاستخدام: انسخ الملف إلى الجهاز، ثم كليك يمين > Run with PowerShell

$ErrorActionPreference = "Stop"
$server = "localhost"          # النسخة الافتراضية MSSQLSERVER
$outFile = Join-Path $PSScriptRoot "schema-report.txt"

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

$master = "Server=$server;Database=master;Integrated Security=True;ApplicationIntent=ReadOnly;TrustServerCertificate=True"
$lines = @()

$lines += "=== Databases ==="
$dbs = Run-Query $master "SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY name"
foreach ($r in $dbs.Rows) { $lines += $r.name }

foreach ($r in $dbs.Rows) {
    $db = $r.name
    $lines += ""
    $lines += "=== Database: $db ==="
    $cs = "Server=$server;Database=$db;Integrated Security=True;ApplicationIntent=ReadOnly;TrustServerCertificate=True"
    try {
        $tables = Run-Query $cs @"
SELECT t.name AS tbl, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name
"@
        $lines += "Tables: $($tables.Rows.Count)"
        foreach ($t in $tables.Rows) { $lines += ("{0}`t{1}" -f $t.tbl, $t.row_count) }

        $lines += ""
        $lines += "--- Columns (table.column type) ---"
        $cols = Run-Query $cs @"
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME, ORDINAL_POSITION
"@
        foreach ($c in $cols.Rows) { $lines += ("{0}.{1} {2}" -f $c.TABLE_NAME, $c.COLUMN_NAME, $c.DATA_TYPE) }
    } catch {
        $lines += "تعذّر قراءة القاعدة: $($_.Exception.Message)"
    }
}

$lines | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "تم. النتيجة في: $outFile"
Read-Host "اضغط Enter للإغلاق"
