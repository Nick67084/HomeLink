require('dotenv').config();
const bcrypt=require('bcryptjs');const db=require('./db');
(async()=>{
 const email=process.env.ADMIN_EMAIL,password=process.env.ADMIN_PASSWORD;
 if(!email||!password||password.length<12)throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD (12+ chars) in .env');
 const hash=await bcrypt.hash(password,12);
 await db.execute("INSERT INTO users(full_name,email,phone,password_hash,role,approved) VALUES('Juristic Officer',?,'0000000000',?,'juristic',TRUE) ON DUPLICATE KEY UPDATE password_hash=VALUES(password_hash),role='juristic',approved=TRUE",[email,hash]);
 console.log('Juristic account ready');await db.end();
})().catch(e=>{console.error(e);process.exit(1)});
