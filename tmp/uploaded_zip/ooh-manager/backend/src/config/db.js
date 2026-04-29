const { Pool } = require("pg");
require("dotenv").config();

const isCloud = process.env.DB_HOST && process.env.DB_HOST.includes("supabase");

const pool = new Pool({
  host:     process.env.DB_HOST     || "localhost",
  port:     parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME     || "ooh_manager",
  user:     process.env.DB_USER     || "postgres",
  password: process.env.DB_PASSWORD || "",
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  ssl: isCloud ? { rejectUnauthorized: false } : false,
});

pool.on("error", (err) => {
  console.error("Erro no pool PostgreSQL:", err.message);
});

async function query(text, params) {
  const res = await pool.query(text, params);
  return res;
}

module.exports = { pool, query };
