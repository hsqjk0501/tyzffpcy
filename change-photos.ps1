# 换照片工具：把「照片源」文件夹里的 11 张照片压缩成 photos/0.jpg~10.jpg 并推送上线
# 用法：把照片放进「照片源」文件夹（第1张=0号樱桃，第11张=10号哈密瓜），双击 换照片.bat
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing

Set-Location $PSScriptRoot
$srcDir = Join-Path $PSScriptRoot '照片源'
$outDir = Join-Path $PSScriptRoot 'photos'

if (-not (Test-Path $srcDir)) {
  Write-Host '没有找到「照片源」文件夹，已自动创建。' -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $srcDir | Out-Null
  Write-Host '请把 11 张照片放进「照片源」文件夹（第1张=0号樱桃，第11张=10号哈密瓜），再双击本工具。' -ForegroundColor Cyan
  Read-Host '按回车键退出'
  exit 1
}

$sortRule = { [regex]::Replace($_.BaseName, '\d+', { param($m) $m.Value.PadLeft(8, '0') }) }
$files = Get-ChildItem $srcDir -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|bmp|gif)$' } | Sort-Object $sortRule
if ($files.Count -lt 11) {
  # 照片源不足 → 直接用 photos/ 里的照片同步游戏内置图片
  $files = Get-ChildItem $outDir -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg)$' } | Sort-Object $sortRule
  if ($files.Count -lt 11) {
    Write-Host "「照片源」文件夹里只有 $($files.Count) 张图片，photos/ 里也不足 11 张，无法继续。" -ForegroundColor Red
    Write-Host '第1张=0号樱桃，第2张=1号橙子 …… 第11张=10号哈密瓜。' -ForegroundColor Cyan
    Read-Host '按回车键退出'
    exit 1
  }
  Write-Host '「照片源」里没有 11 张照片，改用 photos/ 里的照片同步游戏内置图片。' -ForegroundColor Yellow
}

$names = @('樱桃','橙子','柠檬','西瓜','葡萄','桃子','菠萝','猕猴桃','苹果','梨','哈密瓜')
Write-Host '开始压缩照片（居中裁剪成正方形 + 240x240 压缩）...' -ForegroundColor Cyan
for ($i = 0; $i -lt 11; $i++) {
  $f = $files[$i]
  $src = [System.Drawing.Image]::FromFile($f.FullName)
  $side = [Math]::Min($src.Width, $src.Height)
  $x = [Math]::Floor(($src.Width - $side) / 2)
  $y = [Math]::Floor(($src.Height - $side) / 2)
  $srcRect = New-Object System.Drawing.Rectangle($x, $y, $side, $side)
  $bmp = New-Object System.Drawing.Bitmap(240, 240)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0,0,240,240)), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $out = Join-Path $outDir "$i.jpg"
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 72)
  $bmp.Save($out, $codec, $ep)
  $bmp.Dispose()
  $src.Dispose()
  Write-Host "  [$i] $($names[$i])  <-  $($f.Name)"
}
Write-Host ''
Write-Host '正在把新照片写入游戏（替换内置图片）...' -ForegroundColor Cyan

# 替换 index.html 里的内置照片（base64）——推送后游戏直接使用新照片
$indexPath = Join-Path $PSScriptRoot 'index.html'
$html = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('  const PHOTO_DATA = [')
for ($i = 0; $i -lt 11; $i++) {
  $bytes = [IO.File]::ReadAllBytes((Join-Path $outDir "$i.jpg"))
  $b64 = [Convert]::ToBase64String($bytes)
  $comma = ''
  if ($i -lt 10) { $comma = ',' }
  [void]$sb.AppendLine("  'data:image/jpeg;base64,$b64'$comma")
}
[void]$sb.AppendLine('  ];')
$newBlock = $sb.ToString()
$newHtml = [regex]::Replace($html, 'const PHOTO_DATA = \[[\s\S]*?\];', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newBlock })
[IO.File]::WriteAllText($indexPath, $newHtml, (New-Object System.Text.UTF8Encoding $false))
Write-Host '游戏内置照片已替换（index.html），准备推送...' -ForegroundColor Cyan

# 提交并推送
$null = & git add index.html photos/ change-photos.ps1
$null = & git -c user.name='hsqjk0501' -c user.email='656604707@qq.com' commit -m "update photos"
$null = & git -c user.name='hsqjk0501' -c user.email='656604707@qq.com' commit -m "update photos"
$pushOut = & git push origin main 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  Write-Host '推送失败：可能没登录 GitHub。请重试，并在弹出的登录窗口完成登录。' -ForegroundColor Red
  Write-Host $pushOut
  Read-Host '按回车键退出'
  exit 1
}
Write-Host ''
Write-Host '==================== 完成！====================' -ForegroundColor Green
Write-Host '等 1 分钟，然后刷新页面即可看到新照片：' -ForegroundColor Green
Write-Host 'https://hsqjk0501.github.io/tyzffpcy/' -ForegroundColor Cyan
Write-Host '如果还看到旧照片，按 Ctrl+F5 强制刷新一次。' -ForegroundColor Yellow
Read-Host '按回车键退出'