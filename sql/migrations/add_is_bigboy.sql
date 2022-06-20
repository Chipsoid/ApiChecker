ALTER TABLE  `character_sheet`  ADD  `is_bigboy` tinyint(1) NOT NULL DEFAULT 0;
CREATE INDEX `is_bigboy` ON `character_sheet` (`is_bigboy`);