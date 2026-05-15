-- OK_GANGS complete database schema
-- Target: ESX Legacy + oxmysql + ox_inventory + esx_garage
-- Notes:
--   * Import this file before starting the resource.
--   * The CREATE TABLE section is the authoritative fresh-install schema.
--   * The ALTER TABLE section is idempotent for MariaDB/MySQL versions that support
--     ADD COLUMN IF NOT EXISTS and is included so older installs can be upgraded
--     without manually editing every table.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS `ok_gangs_schema_migrations` (
  `version` VARCHAR(32) NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gangs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `created_by_identifier` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=active, 0=inactive/soft-deleted/expired',
  `level` INT UNSIGNED NOT NULL DEFAULT 1,
  `xp` INT UNSIGNED NOT NULL DEFAULT 0,
  `money` BIGINT NOT NULL DEFAULT 0,
  `black_money` BIGINT NOT NULL DEFAULT 0,
  `member_slots` INT UNSIGNED NOT NULL DEFAULT 20,
  `settings` JSON DEFAULT NULL COMMENT 'Dynamic gang options; never store static gangs in config',
  `metadata` JSON DEFAULT NULL,
  `expires_at` DATETIME NOT NULL,
  `deleted_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gangs_name` (`name`),
  KEY `idx_gangs_status_expires` (`status`, `expires_at`),
  KEY `idx_gangs_owner` (`owner_identifier`),
  KEY `idx_gangs_level_xp` (`level`, `xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_ranks` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `salary` INT UNSIGNED NOT NULL DEFAULT 0,
  `permissions` JSON DEFAULT NULL COMMENT 'boss/menu/armory/vehicle/crafting flags by rank',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_rank` (`gang_id`, `rank`),
  KEY `idx_gang_ranks_salary` (`gang_id`, `salary`),
  CONSTRAINT `fk_gang_ranks_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_members` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=active member, 0=removed/left but retained for audit',
  `invited_by_identifier` VARCHAR(64) DEFAULT NULL,
  `last_seen_at` DATETIME DEFAULT NULL,
  `left_at` DATETIME DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_member_identifier` (`identifier`),
  KEY `idx_gang_members_gang` (`gang_id`, `status`, `rank`),
  KEY `idx_gang_members_identifier_status` (`identifier`, `status`),
  CONSTRAINT `fk_gang_members_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_gang_members_rank` FOREIGN KEY (`gang_id`, `rank`) REFERENCES `gang_ranks` (`gang_id`, `rank`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_member_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED DEFAULT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `name` VARCHAR(100) DEFAULT NULL,
  `rank` TINYINT UNSIGNED DEFAULT NULL,
  `action` VARCHAR(32) NOT NULL COMMENT 'join, leave, fire, rank_up, rank_down, migrate_delete',
  `actor_identifier` VARCHAR(64) DEFAULT NULL,
  `reason` VARCHAR(255) DEFAULT NULL,
  `data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_member_history_gang` (`gang_id`, `created_at`),
  KEY `idx_gang_member_history_identifier` (`identifier`, `created_at`),
  CONSTRAINT `fk_gang_member_history_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_locations` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `type` VARCHAR(32) NOT NULL COMMENT 'blip,stash,armory,garage,heli_garage,vehicle_spawn,heli_spawn,vehicle_store,heli_store,boss,crafting',
  `coords` JSON NOT NULL,
  `radius` DECIMAL(8,2) NOT NULL DEFAULT 2.00,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_location_type` (`gang_id`, `type`),
  KEY `idx_gang_locations_enabled` (`gang_id`, `enabled`),
  CONSTRAINT `fk_gang_locations_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_vehicles` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL COMMENT 'Set for personal vehicles parked in gang garage',
  `plate` VARCHAR(12) NOT NULL,
  `model` VARCHAR(60) NOT NULL,
  `label` VARCHAR(100) DEFAULT NULL,
  `type` ENUM('car','helicopter') NOT NULL DEFAULT 'car',
  `props` JSON DEFAULT NULL,
  `stored` TINYINT(1) NOT NULL DEFAULT 1,
  `garage_type` VARCHAR(32) DEFAULT NULL,
  `min_rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `personal` TINYINT(1) NOT NULL DEFAULT 0,
  `spawn_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_spawned_by` VARCHAR(64) DEFAULT NULL,
  `last_spawned_at` DATETIME DEFAULT NULL,
  `last_stored_by` VARCHAR(64) DEFAULT NULL,
  `last_stored_at` DATETIME DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_vehicle_plate` (`plate`),
  KEY `idx_gang_vehicles_gang` (`gang_id`, `stored`, `type`),
  KEY `idx_gang_vehicles_access` (`gang_id`, `type`, `min_rank`),
  KEY `idx_gang_vehicles_owner` (`owner_identifier`),
  CONSTRAINT `fk_gang_vehicles_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_vehicle_access` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `vehicle_model` VARCHAR(60) NOT NULL,
  `vehicle_type` ENUM('car','helicopter') NOT NULL DEFAULT 'car',
  `min_rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_vehicle_access_model` (`gang_id`, `vehicle_model`, `vehicle_type`),
  KEY `idx_gang_vehicle_access_rank` (`gang_id`, `min_rank`, `enabled`),
  CONSTRAINT `fk_gang_vehicle_access_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_gang_vehicle_access_rank` FOREIGN KEY (`gang_id`, `min_rank`) REFERENCES `gang_ranks` (`gang_id`, `rank`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_armory_items` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `item` VARCHAR(80) NOT NULL,
  `label` VARCHAR(100) DEFAULT NULL,
  `min_rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `is_weapon` TINYINT(1) NOT NULL DEFAULT 0,
  `max_take` INT UNSIGNED DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_armory_item` (`gang_id`, `item`),
  KEY `idx_gang_armory_items_rank` (`gang_id`, `min_rank`, `enabled`, `is_weapon`),
  CONSTRAINT `fk_gang_armory_items_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_gang_armory_items_rank` FOREIGN KEY (`gang_id`, `min_rank`) REFERENCES `gang_ranks` (`gang_id`, `rank`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_rank_permissions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL,
  `permission` VARCHAR(64) NOT NULL COMMENT 'armory,item,gun,helicopter,vehicle,boss,crafting,finance,invite,garage',
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `value` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_rank_permission` (`gang_id`, `rank`, `permission`),
  KEY `idx_gang_rank_permissions_enabled` (`gang_id`, `permission`, `enabled`),
  CONSTRAINT `fk_gang_rank_permissions_rank` FOREIGN KEY (`gang_id`, `rank`) REFERENCES `gang_ranks` (`gang_id`, `rank`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_invitations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `target_identifier` VARCHAR(64) DEFAULT NULL,
  `target_source` INT UNSIGNED DEFAULT NULL,
  `invited_by_identifier` VARCHAR(64) NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `status` ENUM('pending','accepted','declined','expired','cancelled') NOT NULL DEFAULT 'pending',
  `expires_at` DATETIME NOT NULL,
  `responded_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_invitations_target` (`target_identifier`, `status`, `expires_at`),
  KEY `idx_gang_invitations_gang` (`gang_id`, `status`, `expires_at`),
  CONSTRAINT `fk_gang_invitations_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_gang_invitations_rank` FOREIGN KEY (`gang_id`, `rank`) REFERENCES `gang_ranks` (`gang_id`, `rank`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_finance_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `identifier` VARCHAR(64) DEFAULT NULL,
  `action` ENUM('deposit_money','withdraw_money','deposit_black','withdraw_black','wash','salary','admin_set') NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `money_before` BIGINT DEFAULT NULL,
  `money_after` BIGINT DEFAULT NULL,
  `black_money_before` BIGINT DEFAULT NULL,
  `black_money_after` BIGINT DEFAULT NULL,
  `wash_cost` BIGINT DEFAULT NULL,
  `online_members` INT UNSIGNED DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_finance_gang_action` (`gang_id`, `action`, `created_at`),
  KEY `idx_gang_finance_identifier` (`identifier`, `created_at`),
  CONSTRAINT `fk_gang_finance_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_salary_payments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL,
  `amount` INT UNSIGNED NOT NULL,
  `paid_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_salary_gang_paid` (`gang_id`, `paid_at`),
  KEY `idx_gang_salary_identifier` (`identifier`, `paid_at`),
  CONSTRAINT `fk_gang_salary_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_xp_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `identifier` VARCHAR(64) DEFAULT NULL,
  `reason` VARCHAR(64) NOT NULL,
  `amount` INT UNSIGNED NOT NULL,
  `level_before` INT UNSIGNED DEFAULT NULL,
  `level_after` INT UNSIGNED DEFAULT NULL,
  `xp_before` INT UNSIGNED DEFAULT NULL,
  `xp_after` INT UNSIGNED DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_xp_events_gang` (`gang_id`, `reason`, `created_at`),
  CONSTRAINT `fk_gang_xp_events_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_level_unlocks` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED DEFAULT NULL COMMENT 'NULL = global unlock rule',
  `level` INT UNSIGNED NOT NULL,
  `unlock_type` VARCHAR(64) NOT NULL COMMENT 'vehicle,helicopter,crafting,slot,armory,item,feature',
  `unlock_key` VARCHAR(100) NOT NULL,
  `value` JSON DEFAULT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_level_unlock` (`gang_id`, `level`, `unlock_type`, `unlock_key`),
  KEY `idx_gang_level_unlocks_level` (`gang_id`, `level`, `enabled`),
  CONSTRAINT `fk_gang_level_unlocks_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_inventory_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED DEFAULT NULL,
  `identifier` VARCHAR(64) DEFAULT NULL,
  `inventory_type` ENUM('stash','armory') NOT NULL,
  `action` ENUM('deposit','withdraw','open') NOT NULL,
  `item` VARCHAR(80) DEFAULT NULL,
  `count` INT DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_inventory_audit_gang` (`gang_id`, `inventory_type`, `action`, `created_at`),
  KEY `idx_gang_inventory_audit_identifier` (`identifier`, `created_at`),
  CONSTRAINT `fk_gang_inventory_audit_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gang_vehicle_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED DEFAULT NULL,
  `identifier` VARCHAR(64) DEFAULT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `action` ENUM('buy','spawn','store','remove','personal_park','personal_unpark') NOT NULL,
  `data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_vehicle_logs_gang` (`gang_id`, `action`, `created_at`),
  KEY `idx_gang_vehicle_logs_plate` (`plate`, `created_at`),
  CONSTRAINT `fk_gang_vehicle_logs_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
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
  KEY `idx_gang_logs_identifier` (`identifier`, `created_at`),
  CONSTRAINT `fk_gang_logs_gang` FOREIGN KEY (`gang_id`) REFERENCES `gangs` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Upgrade helpers for older/incomplete installs. If your database engine does not
-- support ADD COLUMN IF NOT EXISTS, run the CREATE TABLE section on a fresh DB or
-- add the missing columns manually.
ALTER TABLE `gangs`
  ADD COLUMN IF NOT EXISTS `description` VARCHAR(255) DEFAULT NULL AFTER `label`,
  ADD COLUMN IF NOT EXISTS `created_by_identifier` VARCHAR(64) DEFAULT NULL AFTER `owner_identifier`,
  ADD COLUMN IF NOT EXISTS `settings` JSON DEFAULT NULL AFTER `member_slots`,
  ADD COLUMN IF NOT EXISTS `metadata` JSON DEFAULT NULL AFTER `settings`;

ALTER TABLE `gang_ranks`
  ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

ALTER TABLE `gang_members`
  ADD COLUMN IF NOT EXISTS `status` TINYINT(1) NOT NULL DEFAULT 1 AFTER `rank`,
  ADD COLUMN IF NOT EXISTS `invited_by_identifier` VARCHAR(64) DEFAULT NULL AFTER `status`,
  ADD COLUMN IF NOT EXISTS `last_seen_at` DATETIME DEFAULT NULL AFTER `invited_by_identifier`,
  ADD COLUMN IF NOT EXISTS `left_at` DATETIME DEFAULT NULL AFTER `last_seen_at`,
  ADD COLUMN IF NOT EXISTS `metadata` JSON DEFAULT NULL AFTER `left_at`,
  ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `joined_at`;

ALTER TABLE `gang_locations`
  ADD COLUMN IF NOT EXISTS `radius` DECIMAL(8,2) NOT NULL DEFAULT 2.00 AFTER `coords`,
  ADD COLUMN IF NOT EXISTS `metadata` JSON DEFAULT NULL AFTER `enabled`,
  ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `metadata`,
  ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

ALTER TABLE `gang_vehicles`
  ADD COLUMN IF NOT EXISTS `garage_type` VARCHAR(32) DEFAULT NULL AFTER `stored`,
  ADD COLUMN IF NOT EXISTS `spawn_count` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `personal`,
  ADD COLUMN IF NOT EXISTS `last_spawned_by` VARCHAR(64) DEFAULT NULL AFTER `spawn_count`,
  ADD COLUMN IF NOT EXISTS `last_spawned_at` DATETIME DEFAULT NULL AFTER `last_spawned_by`,
  ADD COLUMN IF NOT EXISTS `last_stored_by` VARCHAR(64) DEFAULT NULL AFTER `last_spawned_at`,
  ADD COLUMN IF NOT EXISTS `last_stored_at` DATETIME DEFAULT NULL AFTER `last_stored_by`,
  ADD COLUMN IF NOT EXISTS `metadata` JSON DEFAULT NULL AFTER `last_stored_at`,
  ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

ALTER TABLE `gang_armory_items`
  ADD COLUMN IF NOT EXISTS `label` VARCHAR(100) DEFAULT NULL AFTER `item`,
  ADD COLUMN IF NOT EXISTS `is_weapon` TINYINT(1) NOT NULL DEFAULT 0 AFTER `enabled`,
  ADD COLUMN IF NOT EXISTS `max_take` INT UNSIGNED DEFAULT NULL AFTER `is_weapon`,
  ADD COLUMN IF NOT EXISTS `metadata` JSON DEFAULT NULL AFTER `max_take`,
  ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `metadata`,
  ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

DROP TRIGGER IF EXISTS `trg_gang_members_before_delete`;
DELIMITER $$
CREATE TRIGGER `trg_gang_members_before_delete`
BEFORE DELETE ON `gang_members`
FOR EACH ROW
BEGIN
  INSERT INTO `gang_member_history` (`gang_id`, `identifier`, `name`, `rank`, `action`, `reason`, `data`)
  VALUES (OLD.`gang_id`, OLD.`identifier`, OLD.`name`, OLD.`rank`, 'migrate_delete', 'deleted from active gang_members', JSON_OBJECT('joined_at', OLD.`joined_at`));
END$$
DELIMITER ;

INSERT IGNORE INTO `ok_gangs_schema_migrations` (`version`, `description`) VALUES
('001', 'Initial complete OK_GANGS dynamic schema'),
('002', 'Runtime access, audit, finance, XP, vehicle and member history tables');

SET FOREIGN_KEY_CHECKS = 1;
