CREATE TABLE `user_identifiers` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(255) NOT NULL,
    `name` VARCHAR(255) NULL,
    `license` VARCHAR(255) NULL,
    `date` DATETIME NOT NULL,
    `online` TINYINT(1) NOT NULL,
    PRIMARY KEY (`id`)
);
