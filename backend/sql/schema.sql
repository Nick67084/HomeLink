CREATE TABLE IF NOT EXISTS units (
 id INT AUTO_INCREMENT PRIMARY KEY, building VARCHAR(30) NOT NULL, unit_number VARCHAR(30) NOT NULL,
 UNIQUE KEY unique_unit(building,unit_number)
);
CREATE TABLE IF NOT EXISTS users (
 id INT AUTO_INCREMENT PRIMARY KEY, unit_id INT NULL, full_name VARCHAR(120) NOT NULL,
 email VARCHAR(190) NOT NULL UNIQUE, phone VARCHAR(30) NOT NULL, password_hash VARCHAR(255) NOT NULL,
 role ENUM('resident','juristic') NOT NULL DEFAULT 'resident',
 approved BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (unit_id) REFERENCES units(id)
);
CREATE TABLE IF NOT EXISTS facilities (
 id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) NOT NULL, description TEXT, location VARCHAR(120),
 image_url VARCHAR(500), active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS bookings (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, facility_id INT NOT NULL,
 start_at DATETIME NOT NULL, end_at DATETIME NOT NULL,
 status ENUM('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id),
 FOREIGN KEY(facility_id) REFERENCES facilities(id), INDEX idx_booking_slots(facility_id,start_at,end_at,status)
);
CREATE TABLE IF NOT EXISTS repairs (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, title VARCHAR(150) NOT NULL,
 description TEXT NOT NULL, photo_url VARCHAR(500), status ENUM('pending','in_progress','completed','rejected') NOT NULL DEFAULT 'pending',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS vehicles (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, plate_number VARCHAR(30) NOT NULL,
 vehicle_type VARCHAR(60) NOT NULL, color VARCHAR(50), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES users(id), UNIQUE KEY unique_plate(plate_number)
);
CREATE TABLE IF NOT EXISTS parcels (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, courier VARCHAR(100) NOT NULL,
 tracking_number VARCHAR(120), status ENUM('arrived','collected') NOT NULL DEFAULT 'arrived',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS suggestions (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, subject VARCHAR(150) NOT NULL,
 message TEXT NOT NULL, reply TEXT, status ENUM('open','answered') NOT NULL DEFAULT 'open',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS community_rules (
 id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(150) NOT NULL, content TEXT NOT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS bills (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, title VARCHAR(150) NOT NULL,
 amount DECIMAL(10,2) NOT NULL, due_date DATE NOT NULL, status ENUM('unpaid','paid') NOT NULL DEFAULT 'unpaid',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS messages (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, sender_id INT NOT NULL,
 body TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES users(id), FOREIGN KEY(sender_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS services (
 id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) NOT NULL, description TEXT, price DECIMAL(10,2) NOT NULL DEFAULT 0,
 active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS service_requests (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, service_id INT NOT NULL,
 note TEXT, status ENUM('pending','accepted','completed','cancelled') NOT NULL DEFAULT 'pending',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id), FOREIGN KEY(service_id) REFERENCES services(id)
);
INSERT INTO facilities(name,description,location) VALUES
 ('Study Room','Quiet workspace','Tower A, 2nd Floor'),
 ('Meeting Room','Community meeting space','Tower A, 3rd Floor'),
 ('Fitness Studio','Private fitness area','Tower B, 1st Floor');
INSERT INTO services(name,description,price) VALUES
 ('Home Cleaning','Scheduled apartment cleaning',600.00),
 ('AC Cleaning','Air-conditioner maintenance',850.00),
 ('Laundry Pickup','Laundry collection service',150.00);
