ALTER TABLE  `character_sheet` 
ADD  `home_station_id` INT NOT NULL ,
ADD  `jump_activation` DATETIME NOT NULL ,
ADD  `jump_fatigue` DATETIME NOT NULL ,
ADD  `free_skill_points` INT NOT NULL ,
ADD  `clone_jump_date` DATETIME NOT NULL ,
ADD  `clone_type_id` INT NOT NULL ,
ADD  `free_respecs` INT NOT NULL ,
ADD  `remote_station_date` DATETIME NOT NULL ,
ADD  `jump_last_update` DATETIME NOT NULL ,
ADD  `last_respec_date` DATETIME NOT NULL ,
ADD  `last_timed_respec` DATETIME NOT NULL ;