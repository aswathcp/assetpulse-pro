# AssetPulse-Pro Web Build & Deploy Script

Write-Host "`n🚀 [1/2] Building Flutter Web (Release)..." -ForegroundColor Cyan
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Build failed! Aborting deployment." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n🌐 [2/2] Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Successfully deployed to: https://assetpulse-pro.web.app" -ForegroundColor Green
} else {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
