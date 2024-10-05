docker-compose down
docker-compose build
docker-compose up -d

timeout /t 20

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './import-borehole-data.ps1'"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './import-lidar.ps1'"
