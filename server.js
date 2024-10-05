const fs = require('fs');
const archiver = require('archiver');

const express = require("express");

const pool = require("./db");
const port = 3000;

const app = express();
app.use(express.json());

app.get("/", (req, res) => res.sendStatus(200));
app.post("/", (req, res) => {
  const { name, location } = req.body;
  res.status(200).send({
    message: "Ezeket: " + name + " " + location,
  });
});

// app.get("/raster/:name", async (req, res) => {
//   const tableName = `${req.params.name}_raster`;

//   try {
//     const results = await pool.query(`
//       SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';
//       SELECT ST_AsGDALRaster(rast, 'GTiff') As rastjpg
//       FROM ${tableName}`);

//     // Assuming the raster data is in the last result
//     const selectResult = results[1]; // Results[1] is the SELECT result
//     const rows = selectResult.rows;

//     if (rows.length > 0) {
//       const rasterData = rows[0].rastjpg;
//       if (rasterData) {
//         res.setHeader('Content-Type', 'image/tiff');
//         res.setHeader('Content-Disposition', 'attachment; filename="raster.tif"');
//         let buffer=Buffer.from(rasterData, 'base64')
//         fs.writeFile('raster.tif', buffer, (err) => {
//           if (err) throw err;
//           console.log('File saved!');
//         });
//         res.status(200).send(buffer);
//       } else {
//         res.status(404).send('Raster data not found');
//       }
//     } else { 
//       res.status(404).send('No results found');
//     }
//   } catch (err) {
//     console.error(err);
//     res.sendStatus(500);
//   }
// });
app.get("/raster/:name", async (req, res) => {
  const tableName = `${req.params.name}_raster`;

  const client = await pool.connect();
  try {
    // Execute SET command in the same session
    await client.query(`SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';`);

    const results = await client.query(`
      WITH raster_data AS (
        SELECT 
          ST_AsGDALRaster(rast, 'GTiff') AS rasttif,
          ST_Envelope(rast) AS extent
        FROM ${tableName}
      ),
      boreholes AS (
        SELECT 
          b.*, 
          ST_X(b.geom) AS x,
          ST_Y(b.geom) AS y
        FROM borehole_data b, raster_data
        WHERE ST_Intersects(b.geom, raster_data.extent)
      )
      SELECT
        (SELECT rasttif FROM raster_data LIMIT 1) AS rasttif,
        (SELECT json_agg(to_jsonb(boreholes) - 'geom') FROM boreholes) AS boreholes;
    `);

    client.release();

    if (results.rows.length > 0) {
      const { rasttif, boreholes } = results.rows[0];

      const buffer = Buffer.from(rasttif, 'base64');

      // Set response headers for ZIP file
      res.setHeader('Content-Type', 'application/zip');
      res.setHeader('Content-Disposition', 'attachment; filename="raster_data.zip"');

      // Create the archive
      const archive = archiver('zip', { zlib: { level: 9 } });

      // Handle errors during ZIP creation
      archive.on('error', (err) => {
        console.error('Error creating ZIP:', err);
        res.destroy();
      });

      // Pipe the archive to the response
      archive.pipe(res);

      // Add the TIFF raster to the ZIP
      archive.append(buffer, { name: 'raster.tif' });

      // Add boreholes as a JSON file to the ZIP
      archive.append(JSON.stringify(boreholes, null, 2), { name: 'boreholes.json' });

      // Finalize the ZIP creation process
      archive.finalize();

      // Ensure the response ends when the archive stream finishes
      archive.on('end', () => {
        res.end();
      });
    } else {
      res.status(404).send('No results found');
    }
  } catch (err) {
    console.error(err);
    client.release();
    // Ensure the response is not already being sent before trying to send an error
    if (!res.headersSent) {
      res.sendStatus(500);
    } else {
      res.destroy();
    }
  }
});



app.get("/raster_metadata/:name", async (req, res) => {
  const tableName = `${req.params.name}_raster`;

  try {
    const result = await pool.query(`
SELECT rid, (md).*
FROM (
    SELECT rid, ST_MetaData(rast) AS md
    FROM ${tableName}
) subquery;`);
    res.status(200).json(result.rows);
  } catch (err) {
    console.error(err);
    res.sendStatus(500);
  }
});
app.listen(port, () => console.log("Server has started on port: " + port));
