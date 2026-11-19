
require('dotenv').config();

const bcrypt = require('bcryptjs');
const db = require('./src/db');

async function main() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  const fullName = 'HomeLink Juristic Admin';

  if (!email || !password || password.length < 12) {
    throw new Error(
      'Set ADMIN_EMAIL and ADMIN_PASSWORD (at least 12 characters) in .env'
    );
  }

  const [existing] = await db.execute(
    'SELECT id FROM users WHERE email = ?',
    [email]
  );

  if (existing.length) {
    throw new Error('Email already exists. Choose another admin email.');
  }

  const passwordHash = await bcrypt.hash(password, 12);

  await db.execute(
    `INSERT INTO users
      (unit_id, full_name, email, phone, password_hash, role, approved)
     VALUES (NULL, ?, ?, ?, ?, 'juristic', TRUE)`,
    [fullName, email, '0000000000', passwordHash]
  );

  console.log('Juristic Admin account created successfully!');
}

main()
  .catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => db.end());
