# Define parameters
$lidar_source_dir = "res\lidar"
$borehole_dir = "res\boreholes"
$db_user = "layer-modeller"
$db_pass = "lm123"
$db_name = "layer-modeller-database"
$db_host = "127.0.0.1"
$db_port = "15432"
$table_name = "borehole_data"
$docker_container = "layer-modeller-server-db-1"
$csv_file = "borehole_data.csv"
$borehole_data = @()

#Jsons to csv, copy to docker
Get-ChildItem -Path $borehole_dir -Filter *.json | ForEach-Object {
    $json_file = $_.FullName
    Write-Host "Processing file: $json_file"
    $json_content = Get-Content -Path $json_file -Raw | ConvertFrom-Json
    foreach ($item in $json_content) {
        $geom_wkt = "POINT($($item.eovX) $($item.eovY))"
        $data = @{
            id = $item.id
            jelszam = $item.jelszam
            reteg_mtol = $item.'reteg$mtol'
            reteg_mig = $item.'reteg$mig'
            reteg_lito_nev = $item.'reteg$lito$nev'
            reteg_lito_geo = $item.'reteg$lito$geo'
            geom_text = $geom_wkt
        }
        $borehole_data += New-Object PSObject -Property $data
    }
}
$borehole_data | Export-Csv -Path $csv_file -NoTypeInformation -Encoding UTF8
docker cp $csv_file "${docker_container}:/tmp/"

#create the sql table 
$create_table_sql = @"
DROP TABLE IF EXISTS $table_name;
CREATE TABLE $table_name (
    id INTEGER,
    jelszam TEXT,
    reteg_mtol FLOAT,
    reteg_mig FLOAT,
    reteg_lito_nev TEXT,
    reteg_lito_geo TEXT,
    geom_text TEXT,
    geom geometry(Point, 23700)
);
"@
$create_table_file = "create_borehole_table.sql"
$create_table_sql | Out-File -FilePath $create_table_file -Encoding UTF8
docker cp $create_table_file "${docker_container}:/tmp/"
docker exec -i $docker_container sh -c "psql -U $db_user -d $db_name -f /tmp/$create_table_file"

# copy csv to db
$copy_command = "\COPY $table_name (id, reteg_lito_nev, jelszam, reteg_mtol, reteg_mig, reteg_lito_geo, geom_text) FROM '/tmp/$csv_file' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');"
$copy_sql_file = "copy_borehole_data.sql"
$copy_command | Out-File -FilePath $copy_sql_file -Encoding UTF8
docker cp $copy_sql_file "${docker_container}:/tmp/"
docker exec -i $docker_container sh -c "psql -U $db_user -d $db_name -f /tmp/$copy_sql_file"

# update wkt to geometry
$update_geom_sql = @"
UPDATE $table_name SET geom = ST_GeomFromText(geom_text, 23700);
ALTER TABLE $table_name DROP COLUMN geom_text;
"@
$update_geom_file = "update_geom.sql"
$update_geom_sql | Out-File -FilePath $update_geom_file -Encoding UTF8
docker cp $update_geom_file "${docker_container}:/tmp/"
docker exec -i $docker_container sh -c "psql -U $db_user -d $db_name -f /tmp/$update_geom_file"

Remove-Item $csv_file
Remove-Item $create_table_file
Remove-Item $copy_sql_file
Remove-Item $update_geom_file

Write-Host "All borehole data have been processed and inserted into the database."
