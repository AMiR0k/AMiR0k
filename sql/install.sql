CREATE TABLE IF NOT EXISTS `vehicle_keys` (
    `plate` VARCHAR(16) NOT NULL,
    `display_plate` VARCHAR(16) NOT NULL,
    `owner_identifier` VARCHAR(64) DEFAULT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    `vehicle_model` VARCHAR(64) DEFAULT 'unknown',
    `label` VARCHAR(128) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`),
    INDEX `idx_vehicle_keys_owner` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vehicle_key_permissions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(16) NOT NULL,
    `identifier` VARCHAR(64) NOT NULL,
    `holder_name` VARCHAR(100) DEFAULT NULL,
    `granted_by` VARCHAR(64) DEFAULT NULL,
    `permission_type` ENUM('owner', 'manager', 'shared') NOT NULL DEFAULT 'shared',
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `revoked_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_vehicle_key_holder` (`plate`, `identifier`),
    INDEX `idx_vehicle_key_permissions_identifier` (`identifier`),
    INDEX `idx_vehicle_key_permissions_active` (`plate`, `active`),
    CONSTRAINT `fk_vehicle_key_permissions_plate`
        FOREIGN KEY (`plate`) REFERENCES `vehicle_keys` (`plate`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
