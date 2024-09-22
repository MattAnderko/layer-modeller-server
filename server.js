const fs = require('fs');


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

app.get("/raster/:name", async (req, res) => {
  const tableName = `${req.params.name}_raster`;

  try {
    const results = await pool.query(`
      SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';
      SELECT ST_AsGDALRaster(rast, 'GTiff') As rastjpg
      FROM ${tableName}`);

    // Assuming the raster data is in the last result
    const selectResult = results[1]; // Results[1] is the SELECT result
    const rows = selectResult.rows;

    if (rows.length > 0) {
      const rasterData = rows[0].rastjpg;
      if (rasterData) {
        res.setHeader('Content-Type', 'image/tiff');
        res.setHeader('Content-Disposition', 'attachment; filename="raster.tif"');
        let buffer=Buffer.from(rasterData, 'base64')
        fs.writeFile('raster.tif', buffer, (err) => {
          if (err) throw err;
          console.log('File saved!');
        });
        res.status(200).send(buffer);
      } else {
        res.status(404).send('Raster data not found');
      }
    } else {
      res.status(404).send('No results found');
    }
  } catch (err) {
    console.error(err);
    res.sendStatus(500);
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
