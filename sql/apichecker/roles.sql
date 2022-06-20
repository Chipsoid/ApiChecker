CREATE TABLE `roles` (
 `id` int(11) NOT NULL AUTO_INCREMENT,
 `role` varchar(50) NOT NULL,
 `user_id` int(11) NOT NULL,
 `comment` varchar(200) NOT NULL,
 PRIMARY KEY (`id`),
 KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8