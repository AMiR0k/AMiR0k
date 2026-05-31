-- Import this once before starting the resource so ESX can assign the temporary Oil Runner job.

INSERT INTO `jobs` (`name`, `label`)
VALUES ('oilrunner', 'Oil Runner')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

DELETE FROM `job_grades` WHERE `job_name` = 'oilrunner';

INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`)
VALUES
    ('oilrunner', 0, 'runner', 'Runner', 0, '{}', '{}');
