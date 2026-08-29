@echo off
echo Building Munner-Ai Production Release APK...
cd mobile
flutter build apk --release --dart-define=SUPABASE_URL=https://wclctwwzrzpndkovrqtk.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjbGN0d3d6cnpwbmRrb3ZycXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5OTcxNzksImV4cCI6MjEwMzU3MzE3OX0.mQ5kxTQPikMLPRj82OxbDVAAhGq2ytyDjtsZfsDjTks --dart-define=GOOGLE_WEB_CLIENT_ID=1058997459797-25b8m5a3mpsvscci33jfckalect78ala.apps.googleusercontent.com
cd ..
copy "mobile\build\app\outputs\flutter-apk\app-release.apk" "Munner-Ai-v1.0.apk"
echo APK successfully built and copied to root as Munner-Ai-v1.0.apk!
pause
