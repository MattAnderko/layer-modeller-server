@echo off
setlocal enabledelayedexpansion

:: Set your directory to search for .json files
set "borehole_source_dir=res\boreholes"
:: PostgreSQL/PostGIS database connection parameters
set "db_user=layer-modeller"
set "db_pass=lm123"
set "db_name=layer-modeller-database"
set "db_host=127.0.0.1"
set "db_port=15432"
set "table_name=tif_import"
set "docker_container=layer-modeller-server-db-1"

set "debug=true"

set "id_list="
set "insert_statements="

:: Loop through all JSON files in the directory and extract data
for /r "%borehole_source_dir%" %%f in (*.json) do (
    echo Processing file: %%f
    set "file_name=%%~nxf"

    :: Read the JSON file content into a variable
    set "json_content="
    for /f "usebackq delims=" %%i in (%%f) do (
        set "json_content=!json_content!%%i"
    )

    :: Remove spaces and newlines to simplify parsing
    set "json_content=!json_content: =!"
    set "json_content=!json_content:$=!"

    :: Split the JSON array into individual objects
    setlocal enabledelayedexpansion
    set "object_index=0"
    :parse_loop
    set /a object_index+=1

    :: Extract the next object
    for /f "tokens=1* delims=[{]}" %%a in ("!json_content!") do (
        set "current_object=%%a"
        set "json_content=%%b"
    )

    :: Check if current_object is empty
    if "!current_object!"=="" (
        endlocal
        goto :next_file
    )

    :: Extract fields from the current object
    call :extract_fields "!current_object!"
    endlocal

    :: Append the id to the list of ids for bulk check
    set "id_list=!id_list!!id!,"

    :: Construct bulk insert statement and store it in a variable
    set "insert_statements=!insert_statements!INSERT INTO !table_name! (id, jelszam, eovX, eovY, eovZ, reteg_mtol, reteg_mig, reteg_lito_nev, reteg_lito_geo, oszt, geom) VALUES (!id!, '!jelszam!', !eovX!, !eovY!, !eovZ!, !reteg_mtol!, !reteg_mig!, '!reteg_lito_nev!', '!reteg_lito_geo!', !oszt!, ST_SetSRID(ST_MakePoint(!eovX!, !eovY!), 23700)); "
    goto :parse_loop

    :next_file
)

:: Debug: Print the insert statements
if defined debug (
    echo Insert Statements:
    echo !insert_statements!
)

:: Remove the last comma from the id list
set "id_list=%id_list:~0,-1%"

:: Check which IDs already exist in the database
docker exec -i %docker_container% psql -U %db_user% -d %db_name% -t -c "SELECT id FROM %table_name% WHERE id IN (%id_list%)" > existing_ids.txt

:: Read the existing IDs into a variable
set "existing_ids="
for /f "tokens=*" %%i in (existing_ids.txt) do (
    set "existing_ids=!existing_ids!%%i,"
)

:: Loop through the collected insert statements and insert only if the id doesn't exist
set "to_insert="
for %%s in (!insert_statements!) do (
    for /f "tokens=3 delims=(, " %%i in ("%%s") do (
        if "!existing_ids:%%i=!"=="!existing_ids!" (
            set "to_insert=!to_insert! %%s"
        )
    )
)

:: Perform bulk insert if there are any records to insert
@REM if defined to_insert (
@REM     echo Bulk inserting new records...
@REM     docker exec -i %docker_container% psql -U %db_user% -d %db_name% -c "!to_insert!"
@REM ) else (
@REM     echo No new records to insert.
@REM )

goto :eof

:extract_fields
set "line=%~1"

:: Remove leading and trailing braces
set "line=%line:{=%"
set "line=%line:}=%"

:: Replace commas with newlines
echo %line:,=&echo.%> tmp_fields.txt

:: Initialize variables
set "id="
set "jelszam="
set "eovX="
set "eovY="
set "eovZ="
set "reteg_mtol="
set "reteg_mig="
set "reteg_lito_nev="
set "reteg_lito_geo="
set "oszt="

:: Read fields from tmp_fields.txt
for /f "tokens=1,2 delims=:" %%a in (tmp_fields.txt) do (
    set "key=%%a"
    set "value=%%b"
    set "key=!key:"=!"
    set "value=!value:"=!"

    if "!key!"=="id" set "id=!value!"
    if "!key!"=="jelszam" set "jelszam=!value!"
    if "!key!"=="eovX" set "eovX=!value!"
    if "!key!"=="eovY" set "eovY=!value!"
    if "!key!"=="eovZ" set "eovZ=!value!"
    if "!key!"=="reteg$mtol" set "reteg_mtol=!value!"
    if "!key!"=="reteg$mig" set "reteg_mig=!value!"
    if "!key!"=="reteg$lito$nev" set "reteg_lito_nev=!value!"
    if "!key!"=="reteg$lito$geo" set "reteg_lito_geo=!value!"
    if "!key!"=="oszt" set "oszt=!value!"
)

:: Debugging: Print extracted values
if defined debug (
    echo id=!id!
    echo jelszam=!jelszam!
    echo eovX=!eovX!
    echo eovY=!eovY!
    echo eovZ=!eovZ!
    echo reteg_mtol=!reteg_mtol!
    echo reteg_mig=!reteg_mig!
    echo reteg_lito_nev=!reteg_lito_nev!
    echo reteg_lito_geo=!reteg_lito_geo!
    echo oszt=!oszt!
)
goto :eof
