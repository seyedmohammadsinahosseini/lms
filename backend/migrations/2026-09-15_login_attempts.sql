-- Login throttling: records failed sign-in attempts so login.php can slow down
-- password guessing. Run once against an existing database:
--
--   mysql -u root lms < backend/migrations/2026-09-15_login_attempts.sql
--   (or: sudo mariadb lms < backend/migrations/2026-09-15_login_attempts.sql)
--
-- Fresh installs get this table from schema.sql and do not need this file.

CREATE TABLE IF NOT EXISTS login_attempts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(160) NOT NULL,
  ip VARCHAR(45) NOT NULL,
  attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email_ip_time (email, ip, attempted_at)
) ENGINE=InnoDB;
