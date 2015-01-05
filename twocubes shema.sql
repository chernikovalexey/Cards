--
-- Скрипт сгенерирован Devart dbForge Studio for MySQL, Версия 6.2.280.0
-- Домашняя страница продукта: http://www.devart.com/ru/dbforge/mysql/studio
-- Дата скрипта: 05.01.2015 19:11:32
-- Версия сервера: 5.5.38-0+wheezy1
-- Версия клиента: 4.1
--


USE twocubes;

CREATE TABLE tcardconfigurations (
  `key` VARCHAR(255) NOT NULL,
  value VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`key`)
)
  ENGINE = INNODB
  CHARACTER SET latin1
  COLLATE latin1_swedish_ci;

CREATE TABLE tcardfriendrealations (
  userId           INT(11)    NOT NULL,
  platformFriendId BIGINT(20) NOT NULL,
  platformId       VARCHAR(3) NOT NULL,
  PRIMARY KEY (platformId, platformFriendId, userId)
)
  ENGINE = INNODB
  CHARACTER SET latin1
  COLLATE latin1_swedish_ci;

CREATE TABLE tcardhints (
  chapter INT(11) NOT NULL AUTO_INCREMENT,
  data    TEXT DEFAULT NULL,
  PRIMARY KEY (chapter)
)
  ENGINE = INNODB
  AUTO_INCREMENT = 3
  AVG_ROW_LENGTH = 65536
  CHARACTER SET utf8
  COLLATE utf8_general_ci;

CREATE TABLE tcardnotifications (
  id     INT(11) NOT NULL AUTO_INCREMENT,
  userId INT(11) DEFAULT NULL
  COMMENT 'UserId in twocubes database',
  reason INT(11) DEFAULT NULL,
  data   VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id)
)
  ENGINE = INNODB
  AUTO_INCREMENT = 1
  CHARACTER SET latin1
  COLLATE latin1_swedish_ci;

CREATE TABLE tcardresults (
  id         INT(11) NOT NULL AUTO_INCREMENT,
  userId     INT(11) NOT NULL,
  chapterId  INT(11) NOT NULL,
  levelId    INT(11) NOT NULL,
  result     INT(11) NOT NULL,
  numStatic  INT(11) NOT NULL,
  numDynamic INT(11) NOT NULL,
  time       INT(11) UNSIGNED ZEROFILL DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX UK_tcardresults (chapterId, levelId, userId)
)
  ENGINE = MYISAM
  AUTO_INCREMENT = 10935
  AVG_ROW_LENGTH = 33
  CHARACTER SET utf8
  COLLATE utf8_general_ci;

CREATE TABLE tcardusers (
  userId               INT(11)          NOT NULL AUTO_INCREMENT,
  platformUserId       BIGINT(20)       NOT NULL,
  platformId           VARCHAR(5)       NOT NULL,
  balance              INT(11) UNSIGNED NOT NULL DEFAULT 2
  COMMENT 'Number of hints',
  boughtAttempts       INT(11)          NOT NULL DEFAULT 0
  COMMENT 'Bought attempts',
  dayAttemptsUsed      INT(11)          NOT NULL DEFAULT 0
  COMMENT 'Today used attempts',
  boughtAttemptsUsed   INT(11)          NOT NULL DEFAULT 0,
  totalDayAttemptsUsed INT(11)          NOT NULL DEFAULT 0
  COMMENT 'All attempts used on previous days',
  PRIMARY KEY (userId),
  UNIQUE INDEX UK_tcardusers (platformId, platformUserId)
)
  ENGINE = MYISAM
  AUTO_INCREMENT = 11554
  AVG_ROW_LENGTH = 26
  CHARACTER SET utf8
  COLLATE utf8_general_ci;

CREATE TABLE tunlockedchapters (
  id      INT(11) NOT NULL AUTO_INCREMENT,
  chapter INT(11) DEFAULT NULL,
  userId  INT(11) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX UK_tunlockedchapters (chapter, userId)
)
  ENGINE = INNODB
  AUTO_INCREMENT = 15
  AVG_ROW_LENGTH = 4096
  CHARACTER SET utf8
  COLLATE utf8_general_ci
  COMMENT = 'The chapters user bought';

DELIMITER $$

CREATE DEFINER = 'mysqlroot'@'%'
PROCEDURE notifyFriends(IN userId BIGINT, IN level INT, IN chapter INT, IN result INT)
  BEGIN
    INSERT INTO tcardnotifications (reason, userId, `data`)
      SELECT
        2,
        u.userId,
        CONCAT(chapter, '.', result)
      FROM tcardfriendrealations t
        RIGHT JOIN tcardusers u
          ON t.platformFriendId = u.platformUserId
        RIGHT JOIN tcardresults r
          ON r.userId = u.userId
      WHERE t.userId = userId
            AND r.chapterId = chapter
            AND r.levelId = level
            AND r.result < result;
  END
$$

CREATE DEFINER = 'mysqlroot'@'%'
PROCEDURE setConfig(IN k VARCHAR(255), IN v VARCHAR(255))
  BEGIN
    IF EXISTS(SELECT
                *
              FROM tcardconfigurations
              WHERE `key` = k)
    THEN
      UPDATE tcardconfigurations
      SET `value` = v;
    ELSE
      INSERT INTO tcardconfigurations (`key`, `value`)
        VALUES (k, v);
    END IF;
  END
$$

CREATE
  DEFINER = 'mysqlroot'@'%'
TRIGGER attemptsAdded
AFTER UPDATE
ON tcardusers
FOR EACH ROW
  BEGIN
    IF (NEW.dayAttemptsUsed = 0
        AND OLD.dayAttemptsUsed >= 100)
    THEN
      IF NOT EXISTS(SELECT
                      *
                    FROM tcardnotifications
                    WHERE tcardnotifications.userId = NEW.userId)
      THEN
        INSERT INTO tcardnotifications (userId, reason)
          VALUES (NEW.userId, 0);
      END IF;
    END IF;
  END
$$

CREATE
  DEFINER = 'mysqlroot'@'%'
EVENT clearDayAttempts
  ON SCHEDULE EVERY '1' DAY
STARTS '2014-11-22 07:48:53'
ON COMPLETION PRESERVE
DO
BEGIN
UPDATE twocubes.tcardusers t
SET t.totalDayAttemptsUsed = t.totalDayAttemptsUsed + t.dayAttemptsUsed,
  t.dayAttemptsUsed = 0;
END
$$

ALTER EVENT clearDayAttempts
ENABLE
$$

DELIMITER ;