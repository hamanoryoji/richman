Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:pipeName = 'richonline-local'
$script:snapshot = @{}

function Invoke-Control {
    param([string]$Command, [hashtable]$Payload = @{})
    $pipe = [System.IO.Pipes.NamedPipeClientStream]::new('.', $script:pipeName,
        [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
    try {
        $pipe.Connect(3000)
        $request = @{ version = 1; requestId = [Guid]::NewGuid().ToString('N'); command = $Command; payload = $Payload } |
            ConvertTo-Json -Compress -Depth 12
        $body = [Text.Encoding]::UTF8.GetBytes($request)
        $header = [BitConverter]::GetBytes([uint32]$body.Length)
        foreach ($part in @($header, $body)) { $pipe.Write($part, 0, $part.Length) }
        $pipe.Flush()
        $lenBuf = [byte[]]::new(4); $read = 0
        while ($read -lt 4) { $read += $pipe.Read($lenBuf, $read, 4 - $read) }
        $length = [BitConverter]::ToUInt32($lenBuf, 0)
        $buf = [byte[]]::new($length); $read = 0
        while ($read -lt $length) { $read += $pipe.Read($buf, $read, $length - $read) }
        $reply = [Text.Encoding]::UTF8.GetString($buf) | ConvertFrom-Json
        if ($reply.ok -ne $true) { throw [string]$reply.error.code }
        return $reply.result
    } finally { $pipe.Dispose() }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'RichOnline GM 工具'
$form.Size = New-Object System.Drawing.Size(1000, 640)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$lblPipe = New-Object System.Windows.Forms.Label
$lblPipe.Text = '管道名'; $lblPipe.Location = New-Object System.Drawing.Point(12, 14); $lblPipe.AutoSize = $true
$txtPipe = New-Object System.Windows.Forms.TextBox
$txtPipe.Text = $script:pipeName; $txtPipe.Location = New-Object System.Drawing.Point(66, 10); $txtPipe.Width = 170
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '刷新列表'; $btnRefresh.Location = New-Object System.Drawing.Point(248, 8); $btnRefresh.Width = 90
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = '未连接'; $lblStatus.Location = New-Object System.Drawing.Point(350, 14); $lblStatus.AutoSize = $true

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(12, 42)
$grid.Size = New-Object System.Drawing.Size(640, 330)
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.ReadOnly = $true
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.AutoSizeColumnsMode = 'Fill'

$panel = New-Object System.Windows.Forms.GroupBox
$panel.Text = '角色数值'; $panel.Location = New-Object System.Drawing.Point(666, 42); $panel.Size = New-Object System.Drawing.Size(306, 330)

$fields = @(
    @{ key = 'level';      label = '等级 (0-20)' },
    @{ key = 'experience'; label = '经验' },
    @{ key = 'coins';      label = '金豆' },
    @{ key = 'gold';       label = '金币' },
    @{ key = 'bank';       label = '银行存款' },
    @{ key = 'vip_level';  label = 'VIP (0-3)' },
    @{ key = 'wins';       label = '胜场' },
    @{ key = 'losses';     label = '负场' }
)
$script:boxes = @{}
$y = 24
foreach ($f in $fields) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $f.label; $l.Location = New-Object System.Drawing.Point(12, ($y + 3)); $l.AutoSize = $true
    $b = New-Object System.Windows.Forms.TextBox
    $b.Location = New-Object System.Drawing.Point(130, $y); $b.Width = 160
    $panel.Controls.Add($l); $panel.Controls.Add($b)
    $script:boxes[$f.key] = $b
    $y += 34
}

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = '应用修改'; $btnApply.Location = New-Object System.Drawing.Point(12, 380); $btnApply.Width = 110
$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = '新建账号'; $btnCreate.Location = New-Object System.Drawing.Point(130, 380); $btnCreate.Width = 110
$btnBackup = New-Object System.Windows.Forms.Button
$btnBackup.Text = '备份数据库'; $btnBackup.Location = New-Object System.Drawing.Point(248, 380); $btnBackup.Width = 110
$btnAnnounce = New-Object System.Windows.Forms.Button
$btnAnnounce.Text = '设置公告'; $btnAnnounce.Location = New-Object System.Drawing.Point(366, 380); $btnAnnounce.Width = 110
$btnReload = New-Object System.Windows.Forms.Button
$btnReload.Text = '重载脚本'; $btnReload.Location = New-Object System.Drawing.Point(484, 380); $btnReload.Width = 110

$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point(12, 420); $log.Size = New-Object System.Drawing.Size(960, 165)
$log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true

$form.Controls.AddRange(@($lblPipe, $txtPipe, $btnRefresh, $lblStatus, $grid, $panel,
    $btnApply, $btnCreate, $btnBackup, $btnAnnounce, $btnReload, $log))

function Write-Log([string]$text) {
    $log.AppendText(('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $text) + "`r`n")
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Load-Accounts {
    $script:snapshot = @{}
    $result = Invoke-Control -Command 'accounts.list' -Payload @{ offset = 0; limit = 200 }
    $grid.Rows.Clear()
    if (-not $grid.Columns.Contains('username')) {
        foreach ($c in @('username', 'role_id', 'name', 'level', 'coins', 'gold', 'bank', 'vip')) {
            [void]$grid.Columns.Add($c, $c)
        }
    }
    foreach ($a in $result.accounts) {
        $script:snapshot[[string]$a.role_id] = $a
        $i = $grid.Rows.Add($a.username, $a.role_id, $a.name, $a.level, $a.coins, $a.gold, $a.bank, $a.vip_level)
    }
    Write-Log ("已加载 {0} 个角色" -f $result.accounts.Count)
}

$btnRefresh.Add_Click({
    try {
        $script:pipeName = $txtPipe.Text.Trim()
        Load-Accounts
        $lblStatus.Text = '已连接'
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
    } catch {
        $lblStatus.Text = "失败: $_"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        Write-Log "刷新失败: $_"
    }
})

$grid.Add_SelectionChanged({
    if ($grid.SelectedRows.Count -eq 0) { return }
    $row = $grid.SelectedRows[0]
    $id = [string]$row.Cells[1].Value
    $a = $script:snapshot[$id]
    if (-not $a) { return }
    foreach ($k in $script:boxes.Keys) {
        if ($null -ne $a.$k) { $script:boxes[$k].Text = [string]$a.$k }
    }
})

$btnApply.Add_Click({
    try {
        if ($grid.SelectedRows.Count -eq 0) { throw '先在列表里选一个角色' }
        $id = [string]$grid.SelectedRows[0].Cells[1].Value
        $a = $script:snapshot[$id]
        if (-not $a) { throw '请先刷新列表' }
        $changes = @{}
        $expected = @{}
        foreach ($k in @('level', 'experience', 'coins', 'gold', 'bank', 'vip_level', 'wins', 'losses')) {
            $new = $script:boxes[$k].Text.Trim()
            $old = $a.$k
            if ($k -in @('coins', 'gold', 'bank')) {
                $expected[$k] = [double]$old
                if ([double]$new -ne [double]$old) { $changes[$k] = [double]$new }
            } else {
                $expected[$k] = [int]$old
                if ([int]$new -ne [int]$old) { $changes[$k] = [int]$new }
            }
        }
        if ($changes.Count -eq 0) { throw '没有改动' }
        $roleId = [int]$a.role_id
        $result = Invoke-Control -Command 'accounts.update' -Payload @{
            role_id = $roleId; expected = $expected; changes = $changes; reason = 'GM 工具修改'
        }
        Write-Log ("角色 {0} 已更新: {1}" -f $result.account.name, ($changes.Keys -join ','))
        Load-Accounts
    } catch {
        Write-Log "修改失败: $_"
        [System.Windows.Forms.MessageBox]::Show([string]$_, '修改失败') | Out-Null
    }
})

$btnCreate.Add_Click({
    try {
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = '新建账号'; $dlg.Size = New-Object System.Drawing.Size(320, 190)
        $dlg.StartPosition = 'CenterParent'
        $u = New-Object System.Windows.Forms.TextBox; $u.Location = New-Object System.Drawing.Point(90, 20); $u.Width = 190
        $p = New-Object System.Windows.Forms.TextBox; $p.Location = New-Object System.Drawing.Point(90, 55); $p.Width = 190
        $lu = New-Object System.Windows.Forms.Label; $lu.Text = '用户名'; $lu.Location = New-Object System.Drawing.Point(20, 23); $lu.AutoSize = $true
        $lp = New-Object System.Windows.Forms.Label; $lp.Text = '密码'; $lp.Location = New-Object System.Drawing.Point(20, 58); $lp.AutoSize = $true
        $ok = New-Object System.Windows.Forms.Button; $ok.Text = '创建'; $ok.Location = New-Object System.Drawing.Point(90, 95); $ok.Width = 80; $ok.DialogResult = 'OK'
        $dlg.Controls.AddRange(@($lu, $u, $lp, $p, $ok))
        $dlg.AcceptButton = $ok
        if ($dlg.ShowDialog() -eq 'OK') {
            $result = Invoke-Control -Command 'accounts.create' -Payload @{ username = $u.Text.Trim(); password = $p.Text.Trim() }
            Write-Log ("已创建账号 {0} (role_id {1})" -f $result.account.username, $result.account.role_id)
            Load-Accounts
        }
    } catch { Write-Log "建号失败: $_" }
})

$btnBackup.Add_Click({
    try {
        $result = Invoke-Control -Command 'database.backup'
        Write-Log ("数据库已备份: {0}" -f ($result | ConvertTo-Json -Compress))
    } catch { Write-Log "备份失败: $_" }
})

$btnAnnounce.Add_Click({
    try {
        $cfg = Invoke-Control -Command 'config.get'
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = '公告'; $dlg.Size = New-Object System.Drawing.Size(520, 220); $dlg.StartPosition = 'CenterParent'
        $box = New-Object System.Windows.Forms.TextBox
        $box.Multiline = $true; $box.Location = New-Object System.Drawing.Point(16, 16); $box.Size = New-Object System.Drawing.Size(470, 110)
        $box.Text = [string]$cfg.settings.announcement
        $ok = New-Object System.Windows.Forms.Button; $ok.Text = '保存'; $ok.Location = New-Object System.Drawing.Point(16, 136); $ok.Width = 90; $ok.DialogResult = 'OK'
        $dlg.Controls.AddRange(@($box, $ok)); $dlg.AcceptButton = $ok
        if ($dlg.ShowDialog() -eq 'OK') {
            $settings = $cfg.settings
            $settings.announcement = $box.Text
            Invoke-Control -Command 'config.update' -Payload @{ expectedRevision = $cfg.revision; settings = $settings } | Out-Null
            Write-Log '公告已更新'
        }
    } catch { Write-Log "公告失败: $_" }
})

$btnReload.Add_Click({
    try {
        $r = Invoke-Control -Command 'scripts.reload'
        Write-Log ("脚本已重载: {0}" -f ($r | ConvertTo-Json -Compress))
    } catch { Write-Log "重载失败: $_" }
})

$form.Add_Shown({ try { Load-Accounts; $lblStatus.Text = '已连接'; $lblStatus.ForeColor = [System.Drawing.Color]::Green } catch { Write-Log "连接失败: $_" } })
[void]$form.ShowDialog()
