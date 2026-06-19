param(
    [string]$BucketName = "agrilens-models",
    [string]$Region     = "us-east-1",
    [string]$Prefix     = "models",
    [string]$ModelsDir  = ""
)

if ($ModelsDir -eq "") {
    $ModelsDir = Join-Path $PSScriptRoot "..\models"
}
$ModelsDir = Resolve-Path $ModelsDir

Write-Host ""
Write-Host "========================================"
Write-Host "  AgriLens - Upload Models to S3"
Write-Host "========================================"
Write-Host "Bucket : s3://$BucketName/$Prefix/"
Write-Host "Region : $Region"
Write-Host "Source : $ModelsDir"
Write-Host ""

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI not found. Install: winget install Amazon.AWSCLI"
    exit 1
}

Write-Host "Ensuring bucket exists..." -ForegroundColor Yellow
aws s3api create-bucket --bucket $BucketName --region $Region 2>$null

aws s3api put-public-access-block `
    --bucket $BucketName `
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>$null

Write-Host "Uploading models..." -ForegroundColor Yellow
Write-Host ""

$files = Get-ChildItem -Path $ModelsDir -File
foreach ($file in $files) {
    $key = "$Prefix/$($file.Name)"
    $sizeMB = [math]::Round($file.Length / 1MB, 1)
    $msg = "  Uploading " + $file.Name + " (" + $sizeMB + " MB)..."
    Write-Host $msg -NoNewline

    aws s3 cp $file.FullName "s3://$BucketName/$key" --region $Region --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host " done" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "Upload complete. Verify with:"
Write-Host "  aws s3 ls s3://$BucketName/$Prefix/"
Write-Host ""
Write-Host "Add these to your server .env:"
Write-Host "  AWS_S3_BUCKET=$BucketName"
Write-Host "  AWS_S3_PREFIX=$Prefix"
Write-Host "  AWS_DEFAULT_REGION=$Region"
Write-Host "  AWS_ACCESS_KEY_ID=<your-key>"
Write-Host "  AWS_SECRET_ACCESS_KEY=<your-secret>"
Write-Host "========================================"
