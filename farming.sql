CREATE TABLE IF NOT EXISTS `player_farms` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `uuid` VARCHAR(36) NOT NULL,
  `owner_identifier` VARCHAR(64) NOT NULL,
  `farm_slot` INT UNSIGNED NOT NULL,
  `bucket` INT UNSIGNED NOT NULL,
  `expires_at` INT UNSIGNED NOT NULL,
  `stash_capacity` INT UNSIGNED NOT NULL DEFAULT 250,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_player_farms_uuid` (`uuid`),
  KEY `idx_player_farms_owner` (`owner_identifier`),
  KEY `idx_player_farms_expires` (`expires_at`),
  UNIQUE KEY `uniq_player_farms_slot` (`farm_slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `farm_plants` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `farm_uuid` VARCHAR(36) NOT NULL,
  `slot_id` INT UNSIGNED NOT NULL,
  `seed_item` VARCHAR(64) NOT NULL,
  `product_item` VARCHAR(64) NOT NULL,
  `prop` VARCHAR(96) NOT NULL,
  `planted_at` INT UNSIGNED NOT NULL,
  `locked` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_farm_plants_slot` (`farm_uuid`, `slot_id`),
  KEY `idx_farm_plants_age` (`planted_at`),
  CONSTRAINT `fk_farm_plants_farm` FOREIGN KEY (`farm_uuid`) REFERENCES `player_farms` (`uuid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `farm_access` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `farm_uuid` VARCHAR(36) NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `granted_by` VARCHAR(64) NOT NULL,
  `granted_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_farm_access_farm` (`farm_uuid`),
  KEY `idx_farm_access_identifier` (`identifier`),
  CONSTRAINT `fk_farm_access_farm` FOREIGN KEY (`farm_uuid`) REFERENCES `player_farms` (`uuid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `farm_storage_upgrade` (
  `farm_uuid` VARCHAR(36) NOT NULL,
  `upgraded` TINYINT(1) NOT NULL DEFAULT 0,
  `upgraded_at` INT UNSIGNED NULL DEFAULT NULL,
  PRIMARY KEY (`farm_uuid`),
  CONSTRAINT `fk_farm_storage_upgrade_farm` FOREIGN KEY (`farm_uuid`) REFERENCES `player_farms` (`uuid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
