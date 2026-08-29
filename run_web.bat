@echo off
echo Starting Munner-Ai Flutter Web App in Chrome on port 8080...
cd mobile
flutter run -d chrome --web-port=8080 --dart-define=SUPABASE_URL=https://wclctwwzrzpndkovrqtk.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjbGN0d3d6cnpwbmRrb3ZycXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5OTcxNzksImV4cCI6MjEwMzU3MzE3OX0.mQ5kxTQPikMLPRj82OxbDVAAhGq2ytyDjtsZfsDjTks --dart-define=GOOGLE_WEB_CLIENT_ID=1058997459797-25b8m5a3mpsvscci33jfckalect78ala.apps.googleusercontent.com
pause
