function onUpdateDatabase()
    print("> Updating database to version 31 (guild refuges)")
    db.query([[ 
        CREATE TABLE IF NOT EXISTS `guild_refuges` (
          `id` int unsigned NOT NULL AUTO_INCREMENT,
          `name` varchar(64) NOT NULL,
          `guild_id` int NOT NULL,
          `leader_id` int NOT NULL,
          `level` tinyint unsigned NOT NULL DEFAULT '1',
          `loading_map` varchar(80) NOT NULL,
          `created_at` int unsigned NOT NULL,
          `updated_at` int unsigned NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `guild_refuges_guild` (`guild_id`),
          UNIQUE KEY `guild_refuges_name` (`name`),
          UNIQUE KEY `guild_refuges_map` (`loading_map`),
          FOREIGN KEY (`guild_id`) REFERENCES `guilds` (`id`) ON DELETE CASCADE,
          FOREIGN KEY (`leader_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
    ]])
    return true
end
