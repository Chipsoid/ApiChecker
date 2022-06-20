CREATE TABLE `api` (
    `key` int(11) NOT NULL,
    `vcode` varchar(64) CHARACTER SET utf8 NOT NULL,
    `status` tinyint(4) NOT NULL,
    `type` varchar(25) NOT NULL DEFAULT 'Account',
    `mask` int(11) NOT NULL,
    `user_id` int(11) NOT NULL,
    `added` datetime NOT NULL,
    `deleted` int(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`key`),
    UNIQUE KEY `vcode` (`vcode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

alter table api add index `mask` (`mask`);
alter table api add index `deleted` (`deleted`);
alter table api add index `status` (`status`);