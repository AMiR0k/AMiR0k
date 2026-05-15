CREATE TABLE IF NOT EXISTS `gangs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT(1) NOT NULL DEFAULT 1,
  `level` INT UNSIGNED NOT NULL DEFAULT 1,
  `xp` INT UNSIGNED NOT NULL DEFAULT 0,
  `money` BIGINT NOT NULL DEFAULT 0,
  `black_money` BIGINT NOT NULL DEFAULT 0,
  `member_slots` INT UNSIGNED NOT NULL DEFAULT 20,
  `expires_at` DATETIME NOT NULL,
  `deleted_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gangs_name` (`name`),
  KEY `idx_gangs_status_expires` (`status`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_ranks` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `salary` INT UNSIGNED NOT NULL DEFAULT 0,
  `permissions` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_rank` (`gang_id`, `rank`),
  CONSTRAINT `fk_gang_ranks_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_members` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_member_identifier` (`identifier`),
  KEY `idx_gang_members_gang` (`gang_id`),
  CONSTRAINT `fk_gang_members_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_locations` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `type` VARCHAR(32) NOT NULL,
  `coords` JSON NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_location_type` (`gang_id`, `type`),
  CONSTRAINT `fk_gang_locations_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_vehicles` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `model` VARCHAR(60) NOT NULL,
  `label` VARCHAR(100) DEFAULT NULL,
  `type` ENUM('car','helicopter') NOT NULL DEFAULT 'car',
  `props` JSON DEFAULT NULL,
  `stored` TINYINT(1) NOT NULL DEFAULT 1,
  `min_rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `personal` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_vehicle_plate` (`plate`),
  KEY `idx_gang_vehicles_gang` (`gang_id`, `stored`),
  CONSTRAINT `fk_gang_vehicles_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_armory_items` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `item` VARCHAR(80) NOT NULL,
  `min_rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_armory_item` (`gang_id`, `item`),
  CONSTRAINT `fk_gang_armory_items_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED DEFAULT NULL,
  `identifier` VARCHAR(64) DEFAULT NULL,
  `action` VARCHAR(64) NOT NULL,
  `data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_logs_gang_action` (`gang_id`, `action`, `created_at`),
  CONSTRAINT `fk_gang_logs_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
