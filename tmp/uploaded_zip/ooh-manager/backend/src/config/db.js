const { Pool } = require("pg");
require("dotenv").config();

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || "postgres",
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 15000,
  ssl: { rejectUnauthorized: false },
});

pool.on("error", (err) => {
  console.error("Erro no pool PostgreSQL:", err.message);
});

async function query(text, params) {
  const res = await pool.query(text, params);
  return res;
}

module.exports = { pool, query };
