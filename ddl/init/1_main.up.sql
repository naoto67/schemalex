DROP TABLE IF EXISTS users;
CREATE TABLE users (
  `id` BIGINT NOT NULL DEFAULT 0,
  `name` VARCHAR(256),
  `created_at` DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
  `updated_at` DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARACTER SET utf8mb4;


DROP TABLE IF EXISTS user_items;
CREATE TABLE user_items (
  `id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARACTER SET utf8mb4;