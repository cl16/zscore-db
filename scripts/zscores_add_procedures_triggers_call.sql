-- Define procedures and triggers
-- Intended to be run after DB created, and AFTER initial data load
USE zscores;


-- PROCEDURE: Update all stats for all publication and game scores
DROP PROCEDURE IF EXISTS calc_all_stats_by_pub;
DELIMITER //
CREATE PROCEDURE calc_all_stats_by_pub()
BEGIN
DECLARE n INT DEFAULT 0;
DECLARE i INT DEFAULT 0;
DECLARE pid INT;
DECLARE p_avg DECIMAL(5,2);
DECLARE p_stddev DECIMAL(4,2);
DECLARE gn INT DEFAULT 0;
DECLARE j INT DEFAULT 0;
DECLARE gid INT;
DECLARE g_zscore DECIMAL(4,3);
DECLARE r_score INT;
SELECT COUNT(*) FROM publication INTO n;
SET i=0;
WHILE i < n DO
	SET pid = (SELECT pub_id FROM publication LIMIT i,1);
    SET p_avg = (SELECT ROUND(AVG(review.score), 2) FROM review WHERE review.pub_id = pid);
    SET p_stddev = (SELECT ROUND(STDDEV_POP(review.score), 2) FROM review WHERE review.pub_id = pid);
    UPDATE publication SET publication.score_avg = p_avg WHERE publication.pub_id = pid;
    UPDATE publication SET publication.score_stddev = p_stddev WHERE publication.pub_id = pid;
    SELECT COUNT(*) FROM (SELECT game_id FROM review WHERE review.pub_id = pid) AS temp INTO gn;
    SET j = 0;
    WHILE j < gn DO
        SET gid = (
            SELECT game_id FROM review WHERE review.pub_id = pid
            LIMIT j,1
        );
        SET r_score = (SELECT score FROM review WHERE (review.pub_id = pid) AND (review.game_id = gid));
        SET g_zscore = IF(p_stddev > 0, ROUND((r_score - p_avg) / p_stddev, 3), IF(r_score = p_avg, 0, NULL));
        INSERT INTO stat (game_id, pub_id, zscore)
			VALUES (gid, pid, g_zscore) 
			ON DUPLICATE KEY UPDATE zscore = g_zscore;
        SET j = j + 1;
    END WHILE;
    SET i = i + 1;
END WHILE;
END;
//
DELIMITER ;


-- PROCEDURE: Update one publication's stats and each of its game scores
DROP PROCEDURE IF EXISTS calc_stats_by_pub;
DELIMITER //
CREATE PROCEDURE calc_stats_by_pub(IN pid INT)
BEGIN
DECLARE p_avg DECIMAL(5,2);
DECLARE p_stddev DECIMAL(4,2);
DECLARE gn INT DEFAULT 0;
DECLARE j INT DEFAULT 0;
DECLARE gid INT;
DECLARE g_zscore DECIMAL(4,3);
DECLARE r_score INT;
SET p_avg = (SELECT ROUND(AVG(review.score), 2) FROM review WHERE review.pub_id = pid);
SET p_stddev = (SELECT ROUND(STDDEV_POP(review.score), 2) FROM review WHERE review.pub_id = pid);
UPDATE publication SET publication.score_avg = p_avg WHERE publication.pub_id = pid;
UPDATE publication SET publication.score_stddev = p_stddev WHERE publication.pub_id = pid;
SELECT COUNT(*) FROM (SELECT game_id FROM review WHERE review.pub_id = pid) AS temp INTO gn;
SET j = 0;
WHILE j < gn DO
	SET gid = (
		SELECT game_id FROM review WHERE review.pub_id = pid
		LIMIT j,1
	);
	SET r_score = (SELECT score FROM review WHERE (review.pub_id = pid) AND (review.game_id = gid));
	SET g_zscore = IF(p_stddev > 0, ROUND((r_score - p_avg) / p_stddev, 3), IF(r_score = p_avg, 0, NULL));
	UPDATE stat SET stat.zscore = g_zscore WHERE (stat.pub_id = pid) AND (stat.game_id = gid);
	SET j = j + 1;
END WHILE;
END;
//
DELIMITER ;


-- TRIGGER: After INSERT on review, insert the game-publication row into stat table, then
-- call update procedure on publication and its stats/zscores
DROP TRIGGER IF EXISTS review_insert_pub_stat_update;
DELIMITER //
CREATE TRIGGER review_insert_pub_stat_update AFTER INSERT ON review
	FOR EACH ROW
    BEGIN
		INSERT INTO stat VALUES (NEW.game_id, NEW.pub_id, NULL);
		CALL calc_stats_by_pub(NEW.pub_id);
	END//
DELIMITER ;


-- TRIGGER: After UPDATE on review, call update procedure on publication and its stats/zscores
DROP TRIGGER IF EXISTS review_update_pub_stat_update;
DELIMITER //
CREATE TRIGGER review_update_pub_stat_update AFTER UPDATE ON review
	FOR EACH ROW
    BEGIN
		CALL calc_stats_by_pub(NEW.pub_id);
	END//
DELIMITER ;


-- TRIGGER: Before DELETE on review, delete the corresponding row in stat table
DROP TRIGGER IF EXISTS review_before_delete_pub_stat_update;
DELIMITER //
CREATE TRIGGER review_before_delete_pub_stat_update BEFORE DELETE ON review
	FOR EACH ROW
    BEGIN
		DELETE FROM stat WHERE stat.game_id = OLD.game_id AND stat.pub_id = OLD.pub_id;
	END//
DELIMITER ;


-- TRIGGER: After DELETE on review, call update procedure on publication and its stats/zscores
DROP TRIGGER IF EXISTS review_afterDelete_pub_stat_update;
DELIMITER //
CREATE TRIGGER review_afterDelete_pub_stat_update AFTER DELETE ON review
	FOR EACH ROW
    BEGIN
		CALL calc_stats_by_pub(OLD.pub_id);
	END//
DELIMITER ;
