const { Pool } = require("pg");
const pool = new Pool({
  host: "db",
  port: 5432,
  user: "layer-modeller",
  password: "lm123",
  database: "layer-modeller-database",
});
module.exports = pool;
