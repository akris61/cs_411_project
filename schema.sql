-- Renewable Energy Dashboard — core schema (MySQL 8+)
-- Load with: SOURCE sql/schema.sql;   (after CREATE DATABASE + USE)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Drop in dependency order: junction / fact tables first, then dimensions / owners
DROP TABLE IF EXISTS dashboard_indicators;
DROP TABLE IF EXISTS dashboard_regions;
DROP TABLE IF EXISTS user_saved_dashboards;
DROP TABLE IF EXISTS observations;
DROP TABLE IF EXISTS dashboards;
DROP TABLE IF EXISTS indicators;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- users: people who own dashboards and can save shared layouts
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    role ENUM('viewer', 'analyst', 'admin') NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_users_email UNIQUE (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- regions: geographic areas for renewable metrics (states, countries, ISO-style codes)
-- ---------------------------------------------------------------------------
CREATE TABLE regions (
    region_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(160) NOT NULL,
    country VARCHAR(120) NOT NULL,
    latitude DECIMAL(9,6) NULL,
    longitude DECIMAL(9,6) NULL,
    CONSTRAINT uq_regions_code UNIQUE (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- indicators: measurable series (capacity, generation share, emissions factor, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE indicators (
    indicator_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    name VARCHAR(200) NOT NULL,
    unit VARCHAR(32) NOT NULL,
    category VARCHAR(64) NOT NULL,
    description VARCHAR(512) NULL,
    CONSTRAINT uq_indicators_code UNIQUE (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- dashboards: saved views/charts owned by a user (public or private)
-- ---------------------------------------------------------------------------
CREATE TABLE dashboards (
    dashboard_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    owner_user_id INT UNSIGNED NOT NULL,
    title VARCHAR(200) NOT NULL,
    description VARCHAR(1000) NULL,
    is_public TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_dashboards_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- observations: region, indicator, and date table
-- ---------------------------------------------------------------------------
CREATE TABLE observations (
    observation_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    region_id INT UNSIGNED NOT NULL,
    indicator_id INT UNSIGNED NOT NULL,
    obs_date DATE NOT NULL,
    value DECIMAL(18,6) NOT NULL,
    data_source VARCHAR(200) NULL,
    recorded_by_user_id INT UNSIGNED NULL,
    CONSTRAINT fk_observations_region
        FOREIGN KEY (region_id) REFERENCES regions (region_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_observations_indicator
        FOREIGN KEY (indicator_id) REFERENCES indicators (indicator_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_observations_recorded_by
        FOREIGN KEY (recorded_by_user_id) REFERENCES users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT uq_observations_grain UNIQUE (region_id, indicator_id, obs_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- user_saved_dashboards: bookmarks of dashboards (the user's own or others’ public ones)
-- ---------------------------------------------------------------------------
CREATE TABLE user_saved_dashboards (
    user_id INT UNSIGNED NOT NULL,
    dashboard_id INT UNSIGNED NOT NULL,
    saved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, dashboard_id),
    CONSTRAINT fk_saved_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_saved_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboards (dashboard_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- dashboard_regions: which regions a dashboard focuses on
-- ---------------------------------------------------------------------------
CREATE TABLE dashboard_regions (
    dashboard_id INT UNSIGNED NOT NULL,
    region_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (dashboard_id, region_id),
    CONSTRAINT fk_dr_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboards (dashboard_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_dr_region
        FOREIGN KEY (region_id) REFERENCES regions (region_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- dashboard_indicators: which metrics a dashboard shows
-- ---------------------------------------------------------------------------
CREATE TABLE dashboard_indicators (
    dashboard_id INT UNSIGNED NOT NULL,
    indicator_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (dashboard_id, indicator_id),
    CONSTRAINT fk_di_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboards (dashboard_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_di_indicator
        FOREIGN KEY (indicator_id) REFERENCES indicators (indicator_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;