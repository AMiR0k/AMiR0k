-- ESX Legacy job definition for Oil Runner.
-- این فایل را یک‌بار در دیتابیس سرور اجرا کنید.

INSERT IGNORE INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
    ('oilrunner', 'Oil Runner', 0);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
    ('oilrunner', 0, 'runner', 'Runner', 0, '{}', '{}');
