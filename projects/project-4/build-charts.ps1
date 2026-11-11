$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $projectDir "..\..")
$sourceWorkbook = "C:\Users\JPR1\Downloads\GuttmacherInstituteAbortionDataByState.xlsx"
$workDir = Join-Path $repoRoot ".tmp-guttmacher-xlsx"
$zipPath = Join-Path $workDir "workbook.zip"
$unzipDir = Join-Path $workDir "unzipped"

New-Item -ItemType Directory -Force -Path $workDir | Out-Null
Copy-Item -LiteralPath $sourceWorkbook -Destination $zipPath -Force
if (Test-Path $unzipDir) {
  Remove-Item -LiteralPath $unzipDir -Recurse -Force
}
Expand-Archive -LiteralPath $zipPath -DestinationPath $unzipDir -Force

function Get-ColumnIndex([string]$cellRef) {
  $letters = ([regex]::Match($cellRef, "^[A-Z]+")).Value
  $index = 0
  foreach ($char in $letters.ToCharArray()) {
    $index = ($index * 26) + ([int][char]$char - [int][char]'A' + 1)
  }
  return $index - 1
}

function Get-PlainString($si) {
  if ($si.t) {
    return [string]$si.t
  }
  return (($si.r | ForEach-Object { $_.t }) -join "")
}

function Get-CellValue($cell, $sharedStrings) {
  if ($cell.t -eq "s") {
    return $sharedStrings[[int]$cell.v]
  }
  if ($cell.is) {
    return [string]$cell.is.t
  }
  if ($null -eq $cell.v) {
    return $null
  }
  return [string]$cell.v
}

function Convert-ToNumber($value) {
  if ($null -eq $value) {
    return $null
  }
  $text = [string]$value
  if ($text -eq "" -or $text -eq "n/a" -or $text -eq "nr" -or $text -eq "unavailable") {
    return $null
  }
  if ($text -like "<*") {
    $digits = $text -replace "[^0-9.]", ""
    if ($digits -eq "") { return $null }
    return [double]$digits
  }
  $number = 0.0
  if ([double]::TryParse($text, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
    return $number
  }
  return $null
}

function Html-Encode([string]$text) {
  return [System.Net.WebUtility]::HtmlEncode($text)
}

function New-SvgFrame([int]$width, [int]$height, [string]$title, [string]$subtitle, [string]$body) {
  $encodedTitle = Html-Encode $title
  $encodedSubtitle = Html-Encode $subtitle
  return @"
<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height" role="img" aria-labelledby="title desc">
  <title id="title">$encodedTitle</title>
  <desc id="desc">$encodedSubtitle</desc>
  <rect width="$width" height="$height" fill="#fbfaf7"/>
  <text x="40" y="44" font-family="Inter, Arial, sans-serif" font-size="24" font-weight="700" fill="#1c2833">$encodedTitle</text>
  <text x="40" y="70" font-family="Inter, Arial, sans-serif" font-size="13" fill="#5a6673">$encodedSubtitle</text>
  $body
</svg>
"@
}

function Save-HorizontalBarChart($path, $title, $subtitle, $data, $labelKey, $valueKey, $unit, $color) {
  $width = 980
  $height = 520
  $left = 210
  $right = 70
  $top = 105
  $barHeight = 25
  $gap = 12
  $max = ($data | Measure-Object -Property $valueKey -Maximum).Maximum
  $plotWidth = $width - $left - $right
  $elements = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $data.Count; $i++) {
    $row = $data[$i]
    $value = [double]$row.$valueKey
    $barWidth = if ($max -gt 0) { [math]::Round(($value / $max) * $plotWidth, 1) } else { 0 }
    $y = $top + ($i * ($barHeight + $gap))
    $label = Html-Encode ([string]$row.$labelKey)
    $valueLabel = if ($unit -eq "%") { "{0:N0}%" -f $value } elseif ($unit -eq "rate") { "{0:N1}" -f $value } else { "{0:N0}" -f $value }
    $elements.Add("<text x=""40"" y=""$($y + 18)"" font-family=""Inter, Arial, sans-serif"" font-size=""13"" fill=""#1c2833"">$label</text>")
    $elements.Add("<rect x=""$left"" y=""$y"" width=""$plotWidth"" height=""$barHeight"" rx=""3"" fill=""#ece7de""/>")
    $elements.Add("<rect x=""$left"" y=""$y"" width=""$barWidth"" height=""$barHeight"" rx=""3"" fill=""$color""/>")
    $elements.Add("<text x=""$($left + $barWidth + 8)"" y=""$($y + 18)"" font-family=""Inter, Arial, sans-serif"" font-size=""12"" fill=""#374151"">$valueLabel</text>")
  }
  $elements.Add("<text x=""$left"" y=""490"" font-family=""Inter, Arial, sans-serif"" font-size=""12"" fill=""#5a6673"">Source: Guttmacher Institute state abortion data workbook</text>")
  $svg = New-SvgFrame $width $height $title $subtitle ($elements -join "`n  ")
  Set-Content -LiteralPath $path -Value $svg -Encoding UTF8
}

function Save-DivergingChart($path, $title, $subtitle, $data, $labelKey, $valueKey) {
  $width = 980
  $height = 560
  $left = 210
  $right = 70
  $top = 105
  $barHeight = 23
  $gap = 10
  $plotWidth = $width - $left - $right
  $zeroX = $left + ($plotWidth / 2)
  $maxAbs = ($data | ForEach-Object { [math]::Abs([double]$_.$valueKey) } | Measure-Object -Maximum).Maximum
  $elements = New-Object System.Collections.Generic.List[string]
  $elements.Add("<line x1=""$zeroX"" x2=""$zeroX"" y1=""92"" y2=""506"" stroke=""#8b949e"" stroke-width=""1""/>")
  for ($i = 0; $i -lt $data.Count; $i++) {
    $row = $data[$i]
    $value = [double]$row.$valueKey
    $barWidth = if ($maxAbs -gt 0) { [math]::Round(([math]::Abs($value) / $maxAbs) * ($plotWidth / 2), 1) } else { 0 }
    $x = if ($value -lt 0) { $zeroX - $barWidth } else { $zeroX }
    $y = $top + ($i * ($barHeight + $gap))
    $fill = if ($value -lt 0) { "#b44e5a" } else { "#2f7f78" }
    $label = Html-Encode ([string]$row.$labelKey)
    $valueLabel = if ($value -gt 0) { "+{0:N0}" -f $value } else { "{0:N0}" -f $value }
    $textX = if ($value -lt 0) { $x - 36 } else { $x + $barWidth + 8 }
    $elements.Add("<text x=""40"" y=""$($y + 17)"" font-family=""Inter, Arial, sans-serif"" font-size=""13"" fill=""#1c2833"">$label</text>")
    $elements.Add("<rect x=""$x"" y=""$y"" width=""$barWidth"" height=""$barHeight"" rx=""3"" fill=""$fill""/>")
    $elements.Add("<text x=""$textX"" y=""$($y + 17)"" font-family=""Inter, Arial, sans-serif"" font-size=""12"" fill=""#374151"">$valueLabel</text>")
  }
  $elements.Add("<text x=""$left"" y=""530"" font-family=""Inter, Arial, sans-serif"" font-size=""12"" fill=""#5a6673"">Negative values indicate fewer clinics in 2020 than in 2017.</text>")
  $svg = New-SvgFrame $width $height $title $subtitle ($elements -join "`n  ")
  Set-Content -LiteralPath $path -Value $svg -Encoding UTF8
}

function Save-ScatterPlot($path, $title, $subtitle, $data) {
  $width = 980
  $height = 560
  $left = 82
  $right = 44
  $top = 100
  $bottom = 78
  $plotWidth = $width - $left - $right
  $plotHeight = $height - $top - $bottom
  $rateResidenceColumn = $script:RateResidenceColumn
  $maxX = ($data | Measure-Object -Property $rateResidenceColumn -Maximum).Maximum
  $maxY = ($data | Measure-Object -Property "% of residents obtaining abortions who traveled out of state for care, 2020" -Maximum).Maximum
  $elements = New-Object System.Collections.Generic.List[string]
  $elements.Add("<rect x=""$left"" y=""$top"" width=""$plotWidth"" height=""$plotHeight"" fill=""#fffefa"" stroke=""#d8d1c7""/>")
  for ($i = 0; $i -le 4; $i++) {
    $x = $left + ($i / 4) * $plotWidth
    $y = $top + ($i / 4) * $plotHeight
    $xLabel = "{0:N0}" -f (($i / 4) * $maxX)
    $yLabel = "{0:N0}%" -f ($maxY - (($i / 4) * $maxY))
    $elements.Add("<line x1=""$x"" x2=""$x"" y1=""$top"" y2=""$($top + $plotHeight)"" stroke=""#eee7dc""/>")
    $elements.Add("<line x1=""$left"" x2=""$($left + $plotWidth)"" y1=""$y"" y2=""$y"" stroke=""#eee7dc""/>")
    $elements.Add("<text x=""$($x - 6)"" y=""$($top + $plotHeight + 24)"" font-family=""Inter, Arial, sans-serif"" font-size=""11"" fill=""#5a6673"">$xLabel</text>")
    $elements.Add("<text x=""36"" y=""$($y + 4)"" font-family=""Inter, Arial, sans-serif"" font-size=""11"" fill=""#5a6673"">$yLabel</text>")
  }
  foreach ($row in $data) {
  $xValue = [double]$row.$rateResidenceColumn
    $yValue = [double]$row."% of residents obtaining abortions who traveled out of state for care, 2020"
    $count = [double]$row."No. of abortions, by state of residence, 2020"
    $r = [math]::Max(4, [math]::Min(15, [math]::Sqrt($count) / 18))
    $x = $left + ($xValue / $maxX) * $plotWidth
    $y = $top + $plotHeight - (($yValue / $maxY) * $plotHeight)
    $label = Html-Encode ([string]$row."U.S. State")
    $elements.Add("<circle cx=""$x"" cy=""$y"" r=""$r"" fill=""#2f7f78"" fill-opacity=""0.72"" stroke=""#1f5f59"" stroke-width=""1""><title>$label</title></circle>")
  }
  $elements.Add("<text x=""$($left + 270)"" y=""$($height - 26)"" font-family=""Inter, Arial, sans-serif"" font-size=""12"" fill=""#374151"">Residence abortion rate per 1,000 women aged 15-44</text>")
  $elements.Add("<text x=""18"" y=""330"" transform=""rotate(-90 18 330)"" font-family=""Inter, Arial, sans-serif"" font-size=""12"" fill=""#374151"">% traveling out of state</text>")
  $svg = New-SvgFrame $width $height $title $subtitle ($elements -join "`n  ")
  Set-Content -LiteralPath $path -Value $svg -Encoding UTF8
}

[xml]$sharedXml = Get-Content -LiteralPath (Join-Path $unzipDir "xl\sharedStrings.xml") -Raw -Encoding UTF8
$sharedStrings = @()
foreach ($si in $sharedXml.sst.si) {
  $sharedStrings += Get-PlainString $si
}

[xml]$sheetXml = Get-Content -LiteralPath (Join-Path $unzipDir "xl\worksheets\sheet1.xml") -Raw -Encoding UTF8
$headers = @()
$rows = @()
foreach ($row in $sheetXml.worksheet.sheetData.row) {
  $values = @{}
  foreach ($cell in $row.c) {
    $values[(Get-ColumnIndex $cell.r)] = Get-CellValue $cell $sharedStrings
  }
  if ([int]$row.r -eq 1) {
    for ($i = 0; $i -lt 31; $i++) {
      $headers += $values[$i]
    }
    continue
  }
  $object = [ordered]@{}
  for ($i = 0; $i -lt $headers.Count; $i++) {
    $header = $headers[$i]
    $raw = $values[$i]
    if ($i -eq 0) {
      $object[$header] = $raw
    } else {
      $object[$header] = Convert-ToNumber $raw
    }
  }
  $rows += [pscustomobject]$object
}

$csvPath = Join-Path $projectDir "guttmacher-state-abortion-data.csv"
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$script:RateOccurrenceColumn = $headers | Where-Object { $_ -like "No. of abortions per 1,000 women aged 15*44, by state of occurrence, 2020" } | Select-Object -First 1
$script:RateResidenceColumn = $headers | Where-Object { $_ -like "No. of abortions per 1,000 women aged 15*44, by state of residence, 2020" } | Select-Object -First 1

$topOccurrence = @($rows | Where-Object { $_."No. of abortions, by state of occurrence, 2020" -ne $null } | Sort-Object "No. of abortions, by state of occurrence, 2020" -Descending | Select-Object -First 10)
Save-HorizontalBarChart (Join-Path $projectDir "chart-abortions-occurrence.svg") "Where the most abortions occurred in 2020" "Top 10 states by abortions counted by state of occurrence." $topOccurrence "U.S. State" "No. of abortions, by state of occurrence, 2020" "count" "#366b9f"

$topRates = @($rows | Where-Object { $_.$script:RateResidenceColumn -ne $null } | Sort-Object $script:RateResidenceColumn -Descending | Select-Object -First 10)
Save-HorizontalBarChart (Join-Path $projectDir "chart-residence-rate.svg") "Highest abortion rates by residence" "Top 10 states by abortions per 1,000 women aged 15-44, state of residence, 2020." $topRates "U.S. State" $script:RateResidenceColumn "rate" "#2f7f78"

$travel = @($rows | Where-Object { $_."% of residents obtaining abortions who traveled out of state for care, 2020" -ne $null } | Sort-Object "% of residents obtaining abortions who traveled out of state for care, 2020" -Descending | Select-Object -First 10)
Save-HorizontalBarChart (Join-Path $projectDir "chart-out-of-state-travel.svg") "Residents traveling out of state for abortion care" "Top 10 states by share of residents who crossed state lines for care in 2020." $travel "U.S. State" "% of residents obtaining abortions who traveled out of state for care, 2020" "%" "#8f5f39"

$clinicAccess = @($rows | Where-Object { $_."% of women aged 15-44 living in a county without a clinic, 2020" -ne $null } | Sort-Object "% of women aged 15-44 living in a county without a clinic, 2020" -Descending | Select-Object -First 10)
Save-HorizontalBarChart (Join-Path $projectDir "chart-without-clinic.svg") "Women living in counties without a clinic" "Top 10 states by share of women aged 15-44 living in counties without a clinic in 2020." $clinicAccess "U.S. State" "% of women aged 15-44 living in a county without a clinic, 2020" "%" "#6b5ca5"

$clinicChange = @($rows | Where-Object { $_."Change in the no. of abortion clinics, 2017-2020" -ne $null -and $_."Change in the no. of abortion clinics, 2017-2020" -ne 0 } | Sort-Object { [math]::Abs($_."Change in the no. of abortion clinics, 2017-2020") } -Descending | Select-Object -First 12)
Save-DivergingChart (Join-Path $projectDir "chart-clinic-change.svg") "Largest changes in abortion clinic counts" "States with the largest absolute changes in known clinic counts, 2017-2020." $clinicChange "U.S. State" "Change in the no. of abortion clinics, 2017-2020"

$scatterRows = @($rows | Where-Object { $_.$script:RateResidenceColumn -ne $null -and $_."% of residents obtaining abortions who traveled out of state for care, 2020" -ne $null })
Save-ScatterPlot (Join-Path $projectDir "chart-rate-vs-travel.svg") "Rate and travel tell different access stories" "Each circle is a state; circle size reflects number of resident abortions in 2020." $scatterRows
