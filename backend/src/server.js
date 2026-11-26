
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const db = require('./db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();


const uploadDirectory = path.join(__dirname, '../uploads');

fs.mkdirSync(uploadDirectory, { recursive: true });

const repairPhotoStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDirectory);
  },
  filename: (req, file, cb) => {
    const extension = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp'
    }[file.mimetype];

    cb(null, `${crypto.randomUUID()}${extension || '.jpg'}`);
  }
});

const repairPhotoUpload = multer({
  storage: repairPhotoStorage,
  limits: {
    fileSize: 5 * 1024 * 1024,
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/webp'
    ];
     console.log('Uploaded file:', file.originalname, 'MIME:', file.mimetype);
    if (!allowedTypes.includes(file.mimetype)) {
      return cb(new Error('Only JPG, PNG and WebP images are allowed'));
    }

    cb(null, true);
  }
});


app.disable('x-powered-by');
app.use(helmet());

// FIX 1: Allow Flutter Web on any localhost port.
const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(origin => origin.trim())
  .filter(Boolean);

app.use(cors({
  origin(origin, callback) {
    const local = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin || '');

    if (!origin || local || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Origin not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// FIX 2: Support both /auth and /api/auth.
app.use((req, res, next) => {
  if (req.url === '/auth' || req.url.startsWith('/auth/')) {
    req.url = '/api' + req.url;
  }
  next();
});

app.use(express.json({ limit: '100kb' }));

app.use(
  '/api/auth',
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 40,
    standardHeaders: 'draft-7',
    legacyHeaders: false
  })
);

const asyncRoute = fn => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const bad = (res, msg, code = 400) =>
  res.status(code).json({ error: msg });

const string = (min = 1, max = 500) =>
  z.string().trim().min(min).max(max);

const id = z.coerce.number().int().positive();

const run = async (sql, args = []) => {
  const [rows] = await db.execute(sql, args);
  return rows;
};

// AUTHENTICATION

function auth(req, res, next) {
  const token = (req.headers.authorization || '')
    .replace(/^Bearer /, '');

  try {
    const payload = jwt.verify(
      token,
      process.env.JWT_SECRET,
      { algorithms: ['HS256'] }
    );

    req.user = {
      id: Number(payload.id),
      role: payload.role,
      approved: payload.approved
    };

    next();
  } catch (e) {
    return bad(res, 'Authentication required', 401);
  }
}

function admin(req, res, next) {
  return req.user.role === 'juristic'
    ? next()
    : bad(res, 'Juristic access required', 403);
}

function resident(req, res, next) {
  return req.user.role === 'resident'
    ? next()
    : bad(res, 'Resident access required', 403);
}

function approved(req, res, next) {
  return req.user.role === 'juristic' || req.user.approved
    ? next()
    : bad(res, 'Account awaiting approval', 403);
}

// HEALTH CHECK

app.get('/api/health', asyncRoute(async (req, res) => {
  await run('SELECT 1');

  res.json({
    ok: true,
    service: 'HomeLink API'
  });
}));

// REGISTER

app.post('/api/auth/register', asyncRoute(async (req, res) => {
  const schema = z.object({
    full_name: string(2, 120),
    email: z.string().email().max(190),
    phone: string(6, 30),
    password: string(8, 100),
    building: string(1, 30),
    unit_number: string(1, 30)
  });

  const s = schema.safeParse(req.body);

  if (!s.success) {
    return bad(res, s.error.issues[0].message);
  }

  const {
    full_name,
    email,
    phone,
    password,
    building,
    unit_number
  } = s.data;

  const units = await run(
    'SELECT id FROM units WHERE building=? AND unit_number=?',
    [building, unit_number]
  );

  if (!units.length) {
    return bad(
      res,
      'Unit not found. Ask juristic office to register the unit.',
      400
    );
  }

  const hash = await bcrypt.hash(password, 12);

  try {
    const result = await run(
      `INSERT INTO users
       (unit_id, full_name, email, phone, password_hash, role, approved)
       VALUES (?, ?, ?, ?, ?, 'resident', FALSE)`,
      [
        units[0].id,
        full_name,
        email.toLowerCase(),
        phone,
        hash
      ]
    );

    res.status(201).json({
      id: result.insertId,
      message: 'Registration submitted for approval'
    });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return bad(res, 'Email already registered', 409);
    }

    throw e;
  }
}));

// LOGIN

app.post('/api/auth/login', asyncRoute(async (req, res) => {
  const s = z.object({
    email: z.string().email(),
    password: z.string().min(1)
  }).safeParse(req.body);

  if (!s.success) {
    return bad(res, 'Valid email and password required');
  }

  const rows = await run(
    'SELECT * FROM users WHERE email=?',
    [s.data.email.toLowerCase()]
  );

  const user = rows[0];

  if (
    !user ||
    !(await bcrypt.compare(s.data.password, user.password_hash))
  ) {
    return bad(res, 'Invalid credentials', 401);
  }

  if (
    !process.env.JWT_SECRET ||
    process.env.JWT_SECRET.length < 32
  ) {
    throw new Error('JWT_SECRET must be at least 32 characters');
  }

  const token = jwt.sign(
    {
      id: user.id,
      role: user.role,
      approved: !!user.approved
    },
    process.env.JWT_SECRET,
    {
      expiresIn: '12h',
      algorithm: 'HS256'
    }
  );

  res.json({
    token,
    user: {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      role: user.role,
      approved: !!user.approved
    }
  });
}));

// PROFILE

app.get('/api/me', auth, asyncRoute(async (req, res) => {
  const rows = await run(
    `SELECT
       u.id,
       u.full_name,
       u.email,
       u.phone,
       u.role,
       u.approved,
       x.building,
       x.unit_number
     FROM users u
     LEFT JOIN units x ON x.id = u.unit_id
     WHERE u.id = ?`,
    [req.user.id]
  );

  if (!rows.length) {
    return bad(res, 'Account not found', 404);
  }

  res.json(rows[0]);
}));

app.put('/api/me', auth, asyncRoute(async (req, res) => {
  const s = z.object({
    full_name: string(2, 120),
    phone: string(6, 30)
  }).safeParse(req.body);

  if (!s.success) {
    return bad(res, 'Invalid profile fields');
  }

  await run(
    'UPDATE users SET full_name=?, phone=? WHERE id=?',
    [s.data.full_name, s.data.phone, req.user.id]
  );

  res.json({ message: 'Profile updated' });
}));

// ADMIN: RESIDENT APPROVAL

app.get(
  '/api/admin/residents',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT
         u.id,
         u.full_name,
         u.email,
         u.phone,
         u.approved,
         x.building,
         x.unit_number
       FROM users u
       LEFT JOIN units x ON x.id = u.unit_id
       WHERE role = 'resident'
       ORDER BY u.created_at DESC`
    ));
  })
);

app.put(
  '/api/admin/residents/:id/approve',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const uid = id.safeParse(req.params.id);

    if (!uid.success) {
      return bad(res, 'Invalid resident id');
    }

    const result = await run(
      `UPDATE users
       SET approved=TRUE
       WHERE id=? AND role='resident'`,
      [uid.data]
    );

    if (!result.affectedRows) {
      return bad(res, 'Resident not found', 404);
    }

    res.json({ message: 'Resident approved' });
  })
);

// FACILITIES AND SERVICES

app.get(
  '/api/facilities',
  auth,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      'SELECT * FROM facilities WHERE active=TRUE ORDER BY name'
    ));
  })
);

app.get(
  '/api/services',
  auth,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      'SELECT * FROM services WHERE active=TRUE ORDER BY name'
    ));
  })
);

// FACILITY BOOKINGS

app.get(
  '/api/bookings/my',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT b.*, f.name AS facility_name
       FROM bookings b
       JOIN facilities f ON f.id=b.facility_id
       WHERE b.user_id=?
       ORDER BY b.created_at DESC`,
      [req.user.id]
    ));
  })
);

app.get(
  '/api/admin/bookings',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT b.*, f.name AS facility_name, u.full_name
       FROM bookings b
       JOIN facilities f ON f.id=b.facility_id
       JOIN users u ON u.id=b.user_id
       ORDER BY b.created_at DESC`
    ));
  })
);

app.get(
  '/api/facilities/:id/availability',
  auth,
  approved,
  asyncRoute(async (req, res) => {
    const facility = id.safeParse(req.params.id);
    const start = z.coerce.date().safeParse(req.query.start);
    const end = z.coerce.date().safeParse(req.query.end);

    if (
      !facility.success ||
      !start.success ||
      !end.success ||
      start.data >= end.data
    ) {
      return bad(res, 'Valid facility, start, and end required');
    }

    const rows = await run(
      `SELECT COUNT(*) AS n
       FROM bookings
       WHERE facility_id=?
         AND status IN ('pending','approved')
         AND start_at < ?
         AND end_at > ?`,
      [facility.data, end.data, start.data]
    );

    res.json({ available: Number(rows[0].n) === 0 });
  })
);

app.post(
  '/api/bookings',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    const s = z.object({
      facility_id: id,
      start_at: z.coerce.date(),
      end_at: z.coerce.date()
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid booking fields');
    }

    const { facility_id, start_at, end_at } = s.data;

    if (
      start_at >= end_at ||
      start_at <= new Date() ||
      end_at - start_at > 4 * 3600000
    ) {
      return bad(res, 'Choose a future slot of at most 4 hours');
    }

    const conn = await db.getConnection();

    try {
      await conn.beginTransaction();

      const [facilities] = await conn.execute(
        `SELECT id
         FROM facilities
         WHERE id=? AND active=TRUE
         FOR UPDATE`,
        [facility_id]
      );

      if (!facilities.length) {
        await conn.rollback();
        return bad(res, 'Facility unavailable', 404);
      }

      const [conflicts] = await conn.execute(
        `SELECT id
         FROM bookings
         WHERE facility_id=?
           AND status IN ('pending','approved')
           AND start_at < ?
           AND end_at > ?
         LIMIT 1`,
        [facility_id, end_at, start_at]
      );

      if (conflicts.length) {
        await conn.rollback();
        return bad(res, 'Time slot already booked', 409);
      }

      const [result] = await conn.execute(
        `INSERT INTO bookings
         (user_id, facility_id, start_at, end_at)
         VALUES (?, ?, ?, ?)`,
        [req.user.id, facility_id, start_at, end_at]
      );

      await conn.commit();

      res.status(201).json({
        id: result.insertId,
        message: 'Booking requested'
      });
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  })
);

app.put(
  '/api/bookings/:id/cancel',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    const result = await run(
      `UPDATE bookings
       SET status='cancelled'
       WHERE id=?
         AND user_id=?
         AND status IN ('pending','approved')`,
      [req.params.id, req.user.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Booking cannot be cancelled', 404);
    }

    res.json({ message: 'Booking cancelled' });
  })
);


app.put(
  '/api/admin/bookings/:id/status',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      status: z.enum(['approved', 'rejected'])
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid status');
    }

    const bookingId = id.safeParse(req.params.id);

    if (!bookingId.success) {
      return bad(res, 'Invalid booking ID');
    }

    const conn = await db.getConnection();

    try {
      await conn.beginTransaction();

      // Find the pending booking and its resident.
      const [bookings] = await conn.execute(
        `SELECT b.id, b.user_id, f.name AS facility_name
         FROM bookings b
         JOIN facilities f ON f.id = b.facility_id
         WHERE b.id = ?
           AND b.status = 'pending'
         FOR UPDATE`,
        [bookingId.data]
      );

      if (!bookings.length) {
        await conn.rollback();
        return bad(res, 'Pending booking not found', 404);
      }

      const booking = bookings[0];

      // Update the booking status.
      await conn.execute(
        `UPDATE bookings
         SET status = ?
         WHERE id = ? AND status = 'pending'`,
        [s.data.status, bookingId.data]
      );

      const isApproved = s.data.status === 'approved';

      const title = isApproved
        ? 'Booking Approved'
        : 'Booking Rejected';

      const message = isApproved
        ? `Your ${booking.facility_name} booking has been approved by Juristic Management.`
        : `Your ${booking.facility_name} booking has been rejected by Juristic Management.`;

      // Save a notification for the resident.
      await conn.execute(
        `INSERT INTO notifications
         (user_id, title, message, type, is_read)
         VALUES (?, ?, ?, ?, FALSE)`,
        [
          booking.user_id,
          title,
          message,
          'booking'
        ]
      );

      // Save both changes together.
      await conn.commit();

      res.json({
        message: 'Booking updated and notification created'
      });

    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  })
);


// REPAIRS, VEHICLES AND SUGGESTIONS

const modules = {
  repairs: {
    columns: ['title', 'description', 'photo_url'],
    schema: z.object({
      title: string(2, 150),
      description: string(5, 3000),
      photo_url: z.string().url().max(500).nullable().optional()
    })
  },

  vehicles: {
    columns: ['plate_number', 'vehicle_type', 'color'],
    schema: z.object({
      plate_number: string(2, 30),
      vehicle_type: string(2, 60),
      color: z.string().max(50).nullable().optional()
    })
  },

  suggestions: {
    columns: ['subject', 'message'],
    schema: z.object({
      subject: string(2, 150),
      message: string(5, 3000)
    })
  }
};

for (const [table, cfg] of Object.entries(modules)) {
  app.get(
    `/api/${table}/my`,
    auth,
    resident,
    approved,
    asyncRoute(async (req, res) => {
      res.json(await run(
        `SELECT * FROM ${table}
         WHERE user_id=?
         ORDER BY created_at DESC`,
        [req.user.id]
      ));
    })
  );

  app.get(
    `/api/admin/${table}`,
    auth,
    admin,
    asyncRoute(async (req, res) => {
      res.json(await run(
        `SELECT t.*, u.full_name
         FROM ${table} t
         JOIN users u ON u.id=t.user_id
         ORDER BY t.created_at DESC`
      ));
    })
  );

  app.post(
    `/api/${table}`,
    auth,
    resident,
    approved,
    asyncRoute(async (req, res) => {
      const s = cfg.schema.safeParse(req.body);

      if (!s.success) {
        return bad(res, s.error.issues[0].message);
      }

      const values = cfg.columns.map(
        column => s.data[column] ?? null
      );

      const placeholders = cfg.columns.map(() => '?').join(',');

      const result = await run(
        `INSERT INTO ${table}
         (user_id, ${cfg.columns.join(',')})
         VALUES (?, ${placeholders})`,
        [req.user.id, ...values]
      );

      res.status(201).json({
        id: result.insertId,
        message: 'Created'
      });
    })
  );

  if (table === 'vehicles') {
    app.put(
      `/api/${table}/:id`,
      auth,
      resident,
      approved,
      asyncRoute(async (req, res) => {
        const s = cfg.schema.safeParse(req.body);

        if (!s.success) {
          return bad(res, s.error.issues[0].message);
        }

        const values = cfg.columns.map(
          column => s.data[column] ?? null
        );

        const updates = cfg.columns
          .map(column => `${column}=?`)
          .join(',');

        const result = await run(
          `UPDATE ${table}
           SET ${updates}
           WHERE id=? AND user_id=?`,
          [...values, req.params.id, req.user.id]
        );

        if (!result.affectedRows) {
          return bad(res, 'Not found', 404);
        }

        res.json({ message: 'Updated' });
      })
    );

    app.delete(
      `/api/${table}/:id`,
      auth,
      resident,
      approved,
      asyncRoute(async (req, res) => {
        const result = await run(
          `DELETE FROM ${table}
           WHERE id=? AND user_id=?`,
          [req.params.id, req.user.id]
        );

        if (!result.affectedRows) {
          return bad(res, 'Not found', 404);
        }

        res.json({ message: 'Deleted' });
      })
    );
  }

  if (table === 'repairs') {
    app.put(
      '/api/repairs/:id',
      auth,
      resident,
      approved,
      asyncRoute(async (req, res) => {
        const s = cfg.schema.safeParse(req.body);

        if (!s.success) {
          return bad(res, s.error.issues[0].message);
        }

        const result = await run(
          `UPDATE repairs
           SET title=?, description=?, photo_url=?
           WHERE id=?
             AND user_id=?
             AND status='pending'`,
          [
            s.data.title,
            s.data.description,
            s.data.photo_url ?? null,
            req.params.id,
            req.user.id
          ]
        );

        if (!result.affectedRows) {
          return bad(res, 'Pending repair not found', 404);
        }

        res.json({ message: 'Updated' });
      })
    );
  }
}

// ADMIN REPAIR STATUS


app.put(
  '/api/admin/repairs/:id/status',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      status: z.enum([
        'pending',
        'in_progress',
        'completed',
        'rejected'
      ])
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid repair status');
    }

    const repairId = Number(req.params.id);

    if (!Number.isSafeInteger(repairId) || repairId <= 0) {
      return bad(res, 'Invalid repair ID', 400);
    }

    // Find the repair and its resident.
    const repairs = await run(
      `SELECT id, user_id, title, status
       FROM repairs
       WHERE id = ?`,
      [repairId]
    );

    if (!repairs.length) {
      return bad(res, 'Repair not found', 404);
    }

    const repair = repairs[0];

    // Avoid duplicate notifications when status is unchanged.
    if (repair.status === s.data.status) {
      return res.json({
        message: 'Repair status is already up to date'
      });
    }

    const statusLabels = {
      pending: 'Pending',
      in_progress: 'In Progress',
      completed: 'Completed',
      rejected: 'Rejected'
    };

    const newStatus = s.data.status;
    const statusLabel = statusLabels[newStatus];

    const title = `Repair ${statusLabel}`;
    const message =
      `Your repair request "${repair.title}" ` +
      `has been updated to ${statusLabel} by Juristic Management.`;

    // Update the repair and save its notification together.
    // This transaction prevents partial updates.
    const conn = await db.getConnection();

    try {
      await conn.beginTransaction();

      const [result] = await conn.execute(
        `UPDATE repairs
         SET status = ?
         WHERE id = ?
           AND status = ?`,
        [newStatus, repairId, repair.status]
      );

      if (!result.affectedRows) {
        await conn.rollback();

        return bad(
          res,
          'Repair status changed. Please refresh and try again.',
          409
        );
      }

      await conn.execute(
        `INSERT INTO notifications
         (user_id, title, message, type, is_read)
         VALUES (?, ?, ?, 'repair', FALSE)`,
        [
          repair.user_id,
          title,
          message
        ]
      );

      await conn.commit();

      res.json({
        message: 'Repair updated and notification created'
      });

    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  })
);

// ADMIN SUGGESTION REPLY

app.put(
  '/api/admin/suggestions/:id/reply',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      reply: string(1, 3000)
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Reply required');
    }

    const result = await run(
      `UPDATE suggestions
       SET reply=?, status='answered'
       WHERE id=?`,
      [s.data.reply, req.params.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Suggestion not found', 404);
    }

    res.json({ message: 'Replied' });
  })
);

// PARCELS

app.get(
  '/api/parcels/my',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT * FROM parcels
       WHERE user_id=?
       ORDER BY created_at DESC`,
      [req.user.id]
    ));
  })
);

app.get(
  '/api/admin/parcels',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT p.*, u.full_name
       FROM parcels p
       JOIN users u ON u.id=p.user_id
       ORDER BY p.created_at DESC`
    ));
  })
);


app.post(
  '/api/admin/parcels',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      user_id: id,
      courier: string(2, 100),
      tracking_number: z.string().max(120).nullable().optional()
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid parcel fields');
    }

    const userId = s.data.user_id;
    const courier = s.data.courier;
    const trackingNumber = s.data.tracking_number ?? null;

    // Use a transaction so the parcel and its
    // notification are saved together.
    const conn = await db.getConnection();

    try {
      await conn.beginTransaction();

      // Confirm that the resident exists.
      const [users] = await conn.execute(
        `SELECT id, full_name
         FROM users
         WHERE id = ?
         FOR UPDATE`,
        [userId]
      );

      if (!users.length) {
        await conn.rollback();
        return bad(res, 'Resident not found', 404);
      }

      // Create the parcel.
      const [result] = await conn.execute(
        `INSERT INTO parcels
         (user_id, courier, tracking_number)
         VALUES (?, ?, ?)`,
        [
          userId,
          courier,
          trackingNumber
        ]
      );

      // Prepare the notification.
      const title = 'New Parcel Arrived';

      const message = trackingNumber
        ? `Your parcel from ${courier} (Tracking: ${trackingNumber}) has arrived. Please collect it from the management office.`
        : `Your parcel from ${courier} has arrived. Please collect it from the management office.`;

      // Notify the correct resident.
      await conn.execute(
        `INSERT INTO notifications
         (user_id, title, message, type, is_read)
         VALUES (?, ?, ?, 'parcel', FALSE)`,
        [
          userId,
          title,
          message
        ]
      );

      await conn.commit();

      return res.status(201).json({
        id: result.insertId,
        message: 'Parcel created and resident notified'
      });

    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  })
);


app.put(
  '/api/admin/parcels/:id/collected',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const result = await run(
      `UPDATE parcels
       SET status='collected'
       WHERE id=? AND status='arrived'`,
      [req.params.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Parcel not found', 404);
    }

    res.json({ message: 'Collected' });
  })
);

// COMMUNITY RULES

app.get(
  '/api/rules',
  auth,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      'SELECT * FROM community_rules ORDER BY created_at DESC'
    ));
  })
);

app.post(
  '/api/admin/rules',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      title: string(2, 150),
      content: string(5, 5000)
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid rule');
    }

    const result = await run(
      `INSERT INTO community_rules
       (title, content)
       VALUES (?, ?)`,
      [s.data.title, s.data.content]
    );

    res.status(201).json({ id: result.insertId });
  })
);

app.put(
  '/api/admin/rules/:id',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      title: string(2, 150),
      content: string(5, 5000)
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid rule');
    }

    const result = await run(
      `UPDATE community_rules
       SET title=?, content=?
       WHERE id=?`,
      [s.data.title, s.data.content, req.params.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Not found', 404);
    }

    res.json({ message: 'Updated' });
  })
);

app.delete(
  '/api/admin/rules/:id',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const result = await run(
      'DELETE FROM community_rules WHERE id=?',
      [req.params.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Not found', 404);
    }

    res.json({ message: 'Deleted' });
  })
);

// BILLS

app.get(
  '/api/bills/my',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT * FROM bills
       WHERE user_id=?
       ORDER BY due_date DESC`,
      [req.user.id]
    ));
  })
);

app.get(
  '/api/admin/bills',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT b.*, u.full_name
       FROM bills b
       JOIN users u ON u.id=b.user_id
       ORDER BY due_date DESC`
    ));
  })
);

app.post(
  '/api/admin/bills',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      user_id: id,
      title: string(2, 150),
      amount: z.coerce.number().nonnegative().max(99999999),
      due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid bill');
    }

    const result = await run(
      `INSERT INTO bills
       (user_id, title, amount, due_date)
       VALUES (?, ?, ?, ?)`,
      [
        s.data.user_id,
        s.data.title,
        s.data.amount,
        s.data.due_date
      ]
    );

    res.status(201).json({ id: result.insertId });
  })
);

app.put(
  '/api/admin/bills/:id/status',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      status: z.enum(['paid', 'unpaid'])
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid status');
    }

    const result = await run(
      'UPDATE bills SET status=? WHERE id=?',
      [s.data.status, req.params.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Not found', 404);
    }

    res.json({ message: 'Updated' });
  })
);

// MESSAGES / CONTACT NITI

app.get(
  '/api/messages/my',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT * FROM messages
       WHERE user_id=?
       ORDER BY created_at ASC`,
      [req.user.id]
    ));
  })
);

app.get(
  '/api/admin/messages',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT m.*, u.full_name
       FROM messages m
       JOIN users u ON u.id=m.user_id
       ORDER BY m.created_at DESC`
    ));
  })
);

app.post(
  '/api/messages',
  auth,
  approved,
  asyncRoute(async (req, res) => {
    const s = z.object({
      body: string(1, 2000),
      user_id: id.optional()
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Message required');
    }

    const target = req.user.role === 'juristic'
      ? s.data.user_id
      : req.user.id;

    if (!target) {
      return bad(res, 'Resident id required');
    }

    const found = await run(
      `SELECT id FROM users
       WHERE id=? AND role='resident'`,
      [target]
    );

    if (!found.length) {
      return bad(res, 'Resident not found', 404);
    }

    const result = await run(
      `INSERT INTO messages
       (user_id, sender_id, body)
       VALUES (?, ?, ?)`,
      [target, req.user.id, s.data.body]
    );

    res.status(201).json({ id: result.insertId });
  })
);

// HOME SERVICE REQUESTS

app.get(
  '/api/service-requests/my',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT r.*, s.name AS service_name
       FROM service_requests r
       JOIN services s ON s.id=r.service_id
       WHERE r.user_id=?
       ORDER BY r.created_at DESC`,
      [req.user.id]
    ));
  })
);

app.get(
  '/api/admin/service-requests',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    res.json(await run(
      `SELECT r.*, s.name AS service_name, u.full_name
       FROM service_requests r
       JOIN services s ON s.id=r.service_id
       JOIN users u ON u.id=r.user_id
       ORDER BY r.created_at DESC`
    ));
  })
);

app.post(
  '/api/service-requests',
  auth,
  resident,
  approved,
  asyncRoute(async (req, res) => {
    const s = z.object({
      service_id: id,
      note: z.string().max(2000).optional()
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid service request');
    }

    const found = await run(
      'SELECT id FROM services WHERE id=? AND active=TRUE',
      [s.data.service_id]
    );

    if (!found.length) {
      return bad(res, 'Service not found', 404);
    }

    const result = await run(
      `INSERT INTO service_requests
       (user_id, service_id, note)
       VALUES (?, ?, ?)`,
      [
        req.user.id,
        s.data.service_id,
        s.data.note ?? null
      ]
    );

    res.status(201).json({ id: result.insertId });
  })
);

app.put(
  '/api/admin/service-requests/:id/status',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const s = z.object({
      status: z.enum([
        'pending',
        'accepted',
        'completed',
        'cancelled'
      ])
    }).safeParse(req.body);

    if (!s.success) {
      return bad(res, 'Invalid status');
    }

    const result = await run(
      'UPDATE service_requests SET status=? WHERE id=?',
      [s.data.status, req.params.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Not found', 404);
    }

    res.json({ message: 'Updated' });
  })
);

// ROUTE NOT FOUND


/* =====================================================
   HOMELINK NOTIFICATION SYSTEM
   ===================================================== */

// Get notifications for the logged-in user
app.get(
  '/api/notifications',
  auth,
  asyncRoute(async (req, res) => {
    const notifications = await run(
      `SELECT id, title, message, type, is_read, created_at
       FROM notifications
       WHERE user_id = ?
       ORDER BY created_at DESC, id DESC
       LIMIT 100`,
      [req.user.id]
    );

    res.json(notifications);
  })
);

// Get unread notification count
app.get(
  '/api/notifications/unread-count',
  auth,
  asyncRoute(async (req, res) => {
    const rows = await run(
      `SELECT COUNT(*) AS unread_count
       FROM notifications
       WHERE user_id = ?
         AND is_read = FALSE`,
      [req.user.id]
    );

    res.json({
      unread_count: Number(rows[0].unread_count)
    });
  })
);

// Mark one notification as read
app.put(
  '/api/notifications/:id/read',
  auth,
  asyncRoute(async (req, res) => {
    const notificationId = Number(req.params.id);

    if (
      !Number.isSafeInteger(notificationId) ||
      notificationId <= 0
    ) {
      return bad(res, 'Invalid notification ID', 400);
    }

    const result = await run(
      `UPDATE notifications
       SET is_read = TRUE
       WHERE id = ?
         AND user_id = ?`,
      [notificationId, req.user.id]
    );

    if (!result.affectedRows) {
      return bad(res, 'Notification not found', 404);
    }

    res.json({
      message: 'Notification marked as read'
    });
  })
);

// Mark all notifications as read
app.put(
  '/api/notifications/read-all',
  auth,
  asyncRoute(async (req, res) => {
    await run(
      `UPDATE notifications
       SET is_read = TRUE
       WHERE user_id = ?
         AND is_read = FALSE`,
      [req.user.id]
    );

    res.json({
      message: 'All notifications marked as read'
    });
  })
);

app.use(
  '/uploads',
  express.static(uploadDirectory)
);

app.post(
  '/api/uploads/repair-photo',
  auth,
  (req, res, next) => {
    repairPhotoUpload.single('photo')(req, res, err => {
      if (err) {
        return bad(res, err.message || 'Photo upload failed', 400);
      }

      next();
    });
  },
  asyncRoute(async (req, res) => {
    if (!req.file) {
      return bad(res, 'Please select a photo');
    }

    const photoUrl =
      `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

    res.status(201).json({
      message: 'Photo uploaded successfully',
      url: photoUrl
    });
  })
);


// ==========================================
// COMMUNITY ANNOUNCEMENTS
// ==========================================

const announcementSchema = z.object({
  title: z.string().trim().min(1).max(150),
  content: z.string().trim().min(1).max(10000),
  category: z.enum([
    'general',
    'maintenance',
    'event',
    'emergency'
  ]).default('general'),
  priority: z.enum([
    'normal',
    'important',
    'urgent'
  ]).default('normal')
});

// Resident: View published announcements
app.get('/api/announcements', auth, approved, asyncRoute(async (req, res) => {
  const rows = await run(`
    SELECT *
    FROM announcements
    WHERE is_published = 1
    ORDER BY published_at DESC, id DESC
  `);

  res.json(rows);
}));


/* =========================================
   ADMIN DASHBOARD STATISTICS
========================================= */

app.get(
  '/api/admin/dashboard',
  auth,
  admin,
  asyncRoute(async (req, res) => {

    const rows = await run(`
      SELECT
        (
          SELECT COUNT(*)
          FROM users
          WHERE role = 'resident'
        ) AS total_residents,

        (
          SELECT COUNT(*)
          FROM users
          WHERE role = 'resident'
            AND approved = 0
        ) AS pending_approvals,

        (
          SELECT COUNT(*)
          FROM bookings
          WHERE status = 'pending'
        ) AS pending_bookings,

        (
          SELECT COUNT(*)
          FROM repairs
          WHERE status IN ('pending', 'in_progress')
        ) AS active_repairs,

        (
          SELECT COUNT(*)
          FROM parcels
          WHERE status = 'arrived'
        ) AS unclaimed_parcels,

        (
          SELECT COUNT(*)
          FROM bills
          WHERE status = 'unpaid'
        ) AS unpaid_bills,

        (
          SELECT COUNT(*)
          FROM service_requests
          WHERE status = 'pending'
        ) AS pending_service_requests,

        (
          SELECT COUNT(*)
          FROM announcements
          WHERE is_published = 1
        ) AS published_announcements
    `);

    res.json(rows[0]);
  })
);


// Admin: View all announcements
app.get('/api/admin/announcements', auth, admin, asyncRoute(async (req, res) => {
  const rows = await run(`
    SELECT *
    FROM announcements
    ORDER BY created_at DESC, id DESC
  `);

  res.json(rows);
}));

// Admin: Create announcement
app.post('/api/admin/announcements', auth, admin, asyncRoute(async (req, res) => {
  const parsed = announcementSchema.safeParse(req.body);

  if (!parsed.success) {
    return bad(res, 'Invalid announcement information');
  }

  const { title, content, category, priority } = parsed.data;

  const result = await run(`
    INSERT INTO announcements
      (title, content, category, priority, created_by)
    VALUES (?, ?, ?, ?, ?)
  `, [
    title,
    content,
    category,
    priority,
    req.user.id
  ]);

  res.status(201).json({
    message: 'Announcement created successfully',
    id: result.insertId
  });
}));

// Admin: Update announcement
app.put('/api/admin/announcements/:id', auth, admin, asyncRoute(async (req, res) => {
  const parsed = announcementSchema.safeParse(req.body);

  if (!parsed.success) {
    return bad(res, 'Invalid announcement information');
  }

  const { title, content, category, priority } = parsed.data;

  const result = await run(`
    UPDATE announcements
    SET title = ?, content = ?, category = ?, priority = ?
    WHERE id = ?
  `, [
    title,
    content,
    category,
    priority,
    req.params.id
  ]);

  if (!result.affectedRows) {
    return bad(res, 'Announcement not found', 404);
  }

  res.json({
    message: 'Announcement updated successfully'
  });
}));

// Admin: Publish announcement

app.put(
  '/api/admin/announcements/:id/publish',
  auth,
  admin,
  asyncRoute(async (req, res) => {
    const announcementId = Number(req.params.id);

    if (!Number.isSafeInteger(announcementId) ||
        announcementId <= 0) {
      return bad(res, 'Invalid announcement ID');
    }

    const connection = await db.getConnection();

    try {
      await connection.beginTransaction();

      const [result] = await connection.execute(
        `UPDATE announcements
         SET is_published = 1,
             published_at = CURRENT_TIMESTAMP
         WHERE id = ?
           AND is_published = 0`,
        [announcementId]
      );

      if (!result.affectedRows) {
        await connection.rollback();

        return bad(
          res,
          'Announcement not found or already published'
        );
      }

      const [announcements] = await connection.execute(
        `SELECT title, content
         FROM announcements
         WHERE id = ?`,
        [announcementId]
      );

      const announcement = announcements[0];

      const [notificationResult] =
        await connection.execute(
          `INSERT INTO notifications
            (user_id, title, message, type, is_read)
           SELECT
             id,
             ?,
             ?,
             'announcement',
             0
           FROM users
           WHERE role = 'resident'
             AND approved = 1`,
          [
            announcement.title,
            announcement.content
          ]
        );

      await connection.commit();

      res.json({
        message: 'Announcement published successfully',
        notified_residents:
          notificationResult.affectedRows
      });

    } catch (error) {
      await connection.rollback();
      throw error;

    } finally {
      connection.release();
    }
  })
);


// Admin: Delete announcement
app.delete('/api/admin/announcements/:id', auth, admin, asyncRoute(async (req, res) => {
  const result = await run(`
    DELETE FROM announcements
    WHERE id = ?
  `, [req.params.id]);

  if (!result.affectedRows) {
    return bad(res, 'Announcement not found', 404);
  }

  res.json({
    message: 'Announcement deleted successfully'
  });
}));



app.use((req, res) => {
  return bad(res, 'Route not found', 404);
});

// ERROR HANDLER

app.use((err, req, res, next) => {
  console.error(err);

  if (err.code === 'ER_DUP_ENTRY') {
    return bad(res, 'Duplicate record', 409);
  }

  if (err.code === 'ER_NO_REFERENCED_ROW_2') {
    return bad(res, 'Referenced record not found', 400);
  }

  if (err instanceof SyntaxError && 'body' in err) {
    return bad(res, 'Invalid JSON');
  }

  return bad(res, 'Internal server error', 500);
});

// START SERVER

if (require.main === module) {
  const port = 3001;

  app.listen(port, () => {
    console.log(`HomeLink API on ${port}`);
  });
}

module.exports = app;
