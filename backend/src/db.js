require('dotenv').config();
const mysql = require('mysql2/promise');
const pool = mysql.createPool({
 host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 4000),
 user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME,
 waitForConnections: true, connectionLimit: 5, decimalNumbers: true,
 ssl: process.env.DB_SSL === 'true' ? { minVersion: 'TLSv1.2' } : undefined,
 timezone: 'Z'
});
module.exports = pool;
