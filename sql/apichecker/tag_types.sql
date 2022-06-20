CREATE TABLE IF NOT EXISTS `tag_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `color` varchar(20) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=5 ;

--
-- Дамп данных таблицы `tag_types`
--

INSERT INTO `tag_types` (`id`, `color`) VALUES
(1, 'red'),
(2, 'green'),
(3, 'blue'),
(4, 'purple');
