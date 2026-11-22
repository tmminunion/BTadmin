# BTadmin

Aplikasi Android panel kendali admin **Bungtemin** (`com.bung.btadmin`).

## Auto-Build & Deploy (CI/CD)
- Repositori ini bersifat **public**, sehingga setiap `git push` ke branch `main` (maupun trigger manual `workflow_dispatch`) otomatis menjalankan workflow `.github/workflows/build-apk.yml`.
- `versionCode` otomatis bertambah di setiap build (`BASE_CODE + GITHUB_RUN_NUMBER`).
- APK rilis yang sudah ditandatangani otomatis diunggah ke folder Google Drive (hanya mempertahankan 1 file APK terbaru) dan link download-nya dikirim ke Telegram.
