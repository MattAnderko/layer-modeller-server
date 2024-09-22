@echo off
setlocal enabledelayedexpansion

:: Set your directory to search for .tif files
set "search_dir=res\lidar"

:: PostgreSQL/PostGIS database connection parameters
set "db_user=layer-modeller"
set "db_pass=lm123"
set "db_name=layer-modeller-database"
set "db_host=127.0.0.1"
set "db_port=15432"
set "table_name=tif_import"

:: Docker container name for the PostGIS container
set "docker_container=layer-modeller-server-db-1"

:: Debug mode: enable to see more output
set "debug=true"

:: Create directory inside the container to hold .tif files
docker exec %docker_container% mkdir -p /tmp/tif_files

:: Loop through all .tif files in the directory and its subdirectories
for /r "%search_dir%" %%f in (*.tif) do (
    echo Importing file: %%f

    :: Get the filename
    set "file_name=%%~nxf"
    echo !filename! SZIA
    set "area_name=%%~nf_raster"
    echo !area_name!
    :: Check if the Docker container is running
    docker inspect -f "{{.State.Running}}" %docker_container% 2>NUL | find "true" >NUL
    if errorlevel 1 (
        echo Docker container %docker_container% is not running. Aborting...
        exit /b 1
    )

    :: Copy the .tif file into the container
    if "%debug%"=="true" (
        echo Copying %%f to container %docker_container%:/tmp/tif_files/
    )
    docker cp "%%f" %docker_container%:/tmp/tif_files/

    :: Run the raster2pgsql command inside the container using the copied file
    if "%debug%"=="true" (
        echo Executing inside container: raster2pgsql -s 23700 -I -C -M "/tmp/tif_files/!file_name!" public.!area_name!"
    )

    docker exec -i %docker_container% sh -c "raster2pgsql -s 23700 -I -C -M '/tmp/tif_files/!file_name!' !area_name! | psql -U %db_user% -d %db_name%"

    :: Check the exit code for success or failure
    if errorlevel 1 (
        echo Failed to import file: %%f
        exit /b 1
    ) else (
        echo Successfully imported file: %%f
    )
)

echo All .tif files have been processed.
endlocal
pause
