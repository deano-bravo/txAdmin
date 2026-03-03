-- ============================================================================
-- MariaDB initialization for txAdmin stack
-- Executed once on first container start (when mariadb_data volume is empty)
-- ============================================================================

-- Ensure the txadmin database exists with proper charset
CREATE DATABASE IF NOT EXISTS `txadmin`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Grant least-privilege access to the txadmin service user.
-- The user is created by MARIADB_USER / MARIADB_PASSWORD env vars;
-- this ensures it has access to the database without admin capabilities.
-- Intentionally excludes: DROP, GRANT, SUPER, PROCESS, FILE
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, EXECUTE, REFERENCES
    ON `txadmin`.* TO 'txadmin'@'%';
FLUSH PRIVILEGES;
