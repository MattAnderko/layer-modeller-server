$search_dir = "res\lidar"

$db_user = "layer-modeller"
$db_pass = "lm123"
$db_name = "layer-modeller-database"
$db_host = "127.0.0.1"
$db_port = 15432
$table_name = "tif_import"
$docker_container = "layer-modeller-server-db-1"
$debug = $true

docker exec $docker_container mkdir -p /tmp/tif_files
docker exec -i $docker_container sh -c "psql -U $db_user -d $db_name -c 'CREATE EXTENSION IF NOT EXISTS postgis_raster;'"

Get-ChildItem -Path $search_dir -Filter *.tif -Recurse | ForEach-Object {
    $file = $_.FullName
    $file_name = $_.Name
    $area_name = "$($_.BaseName)_raster"

    Write-Host "Importing file: $file"
    Write-Host $area_name

    docker cp $file "${docker_container}:/tmp/tif_files/"
    docker exec -i $docker_container sh -c "raster2pgsql -s 23700 -I -C -M '/tmp/tif_files/$file_name' $area_name | psql -U $db_user -d $db_name"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to import file: $file"
        exit 1
    } else {
        Write-Host "Successfully imported file: $file"
    }
}

Write-Host "All .tif files have been processed."