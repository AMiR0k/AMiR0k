-- Optional but recommended registration table for Oil Runner Tug ownership/state.
-- Import this file into your ESX database before starting the resource.
-- The server also keeps live memory state; this table documents/registers each active Tug
-- by player identifier, generated plate and network id for easier validation/debugging.

CREATE TABLE IF NOT EXISTS `oilrunner_active_tugs` (
    `identifier` VARCHAR(64) NOT NULL,
    `source` INT NOT NULL,
    `plate` VARCHAR(16) NOT NULL,
    `net_id` INT NOT NULL,
    `deposit_paid` TINYINT(1) NOT NULL DEFAULT 1,
    `has_oil` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`),
    UNIQUE KEY `uniq_oilrunner_plate` (`plate`),
    KEY `idx_oilrunner_net_id` (`net_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
