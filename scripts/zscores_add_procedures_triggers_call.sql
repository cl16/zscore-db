-- Define procedures and triggers
-- Intended to be run after DB created, and AFTER initial data load
USE zscores;

-- PROCEDURE to apply a publication's average score and its standard deviation to its publication table row
DROP PROCEDURE IF EXISTS usp_all_pub_game_calcs;
DELIMITER //
CREATE PROCEDURE usp_all_pub_game_calcs()
BEGIN
-- publication vars
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
	SET pid = (SELECT publicationId FROM publication LIMIT i,1);
    SET p_avg = (SELECT ROUND(AVG(review.score), 2) FROM review WHERE review.publication_publicationId = pid);
    SET p_stddev = (SELECT ROUND(STDDEV_POP(review.score), 2) FROM review WHERE review.publication_publicationId = pid);
    UPDATE publication SET publication.score_avg = p_avg WHERE publication.publicationId = pid;
    UPDATE publication SET publication.score_stddev = p_stddev WHERE publication.publicationId = pid;

    -- update game table
    SELECT COUNT(*) FROM (SELECT game_gameId FROM review WHERE review.publication_publicationId = pid) AS temp INTO gn;
    SET j = 0;
    WHILE j < gn DO
        SET gid = (
            SELECT game_gameId FROM review WHERE review.publication_publicationId = pid
            LIMIT j,1
        );
        SET r_score = (SELECT score FROM review WHERE (review.publication_publicationId = pid) AND (review.game_gameId = gid));
        SET g_zscore = IF(p_stddev > 0, ROUND((r_score - p_avg) / p_stddev, 3), IF(r_score = p_avg, 0, NULL));
        -- UPDATE review SET review.zscore = g_zscore WHERE (review.publication_publicationId = pid) AND (review.game_gameId = gid);
        INSERT INTO stat (game_gameId, publication_publicationId, zscore)
			VALUES (gid, pid, g_zscore) 
			ON DUPLICATE KEY UPDATE zscore = g_zscore;
        SET j = j + 1;
    END WHILE;
    SET i = i + 1;
END WHILE;
END;
//
DELIMITER ;


-- PROCEDURE: Update one publication's avg and stddev values, then update the zscores for all of its games using those updated values.
-- delete first
DROP PROCEDURE IF EXISTS usp_one_pub_game_calcs;
DELIMITER //
CREATE PROCEDURE usp_one_pub_game_calcs(
	IN pid INT
)
BEGIN
-- publication vars
DECLARE p_avg DECIMAL(5,2);
DECLARE p_stddev DECIMAL(4,2);
DECLARE gn INT DEFAULT 0;
DECLARE j INT DEFAULT 0;
DECLARE gid INT;
DECLARE g_zscore DECIMAL(4,3);
DECLARE r_score INT;
-- update publication table
SET p_avg = (SELECT ROUND(AVG(review.score), 2) FROM review WHERE review.publication_publicationId = pid);
SET p_stddev = (SELECT ROUND(STDDEV_POP(review.score), 2) FROM review WHERE review.publication_publicationId = pid);
UPDATE publication SET publication.score_avg = p_avg WHERE publication.publicationId = pid;
UPDATE publication SET publication.score_stddev = p_stddev WHERE publication.publicationId = pid;
-- update review table
SELECT COUNT(*) FROM (SELECT game_gameId FROM review WHERE review.publication_publicationId = pid) AS temp INTO gn;
SET j = 0;
WHILE j < gn DO
	SET gid = (
		SELECT game_gameId FROM review WHERE review.publication_publicationId = pid
		LIMIT j,1
	);
	SET r_score = (SELECT score FROM review WHERE (review.publication_publicationId = pid) AND (review.game_gameId = gid));
	SET g_zscore = IF(p_stddev > 0, ROUND((r_score - p_avg) / p_stddev, 3), IF(r_score = p_avg, 0, NULL));
	UPDATE stat SET stat.zscore = g_zscore WHERE (stat.publication_publicationId = pid) AND (stat.game_gameId = gid);
	SET j = j + 1;
END WHILE;
END;
//
DELIMITER ;


-- PROCEDURE - Call the procedure to make updates on all statistical data
CALL usp_all_pub_game_calcs();


-- TRIGGERS
-- After INSERT on review, insert the game-publication row into stat table,
-- then call update procedure on publication and its stats/zscores
-- delete first
DROP TRIGGER IF EXISTS review_insert_pubStatUpdate;
-- Trigger for updating publication and game stats on review insert
DELIMITER //
CREATE TRIGGER review_insert_pubStatUpdate AFTER INSERT ON review
	FOR EACH ROW
    BEGIN
		INSERT INTO stat VALUES (NEW.game_gameId, NEW.publication_publicationId, NULL);
		CALL usp_one_pub_game_calcs(NEW.publication_publicationId);
	END//
DELIMITER ;


-- After UPDATE on review, call update procedure on publication and its stats/zscores
-- delete first
DROP TRIGGER IF EXISTS review_update_pubStatUpdate;
-- Trigger for updating publication and game stats on review insert
DELIMITER //
CREATE TRIGGER review_update_pubStatUpdate AFTER UPDATE ON review
	FOR EACH ROW
    BEGIN
		CALL usp_one_pub_game_calcs(NEW.publication_publicationId);
	END//
DELIMITER ;


-- Before DELETE on review, delete the corresponding row in stat table
-- delete first
DROP TRIGGER IF EXISTS review_beforeDelete_pubStatUpdate;
-- Trigger for updating publication and game stats on review insert
DELIMITER //
CREATE TRIGGER review_beforeDelete_pubStatUpdate BEFORE DELETE ON review
	FOR EACH ROW
    BEGIN
		DELETE FROM stat WHERE stat.game_gameId = OLD.game_gameId AND stat.publication_publicationId = OLD.publication_publicationId;
	END//
DELIMITER ;


-- After DELETE on review, call update procedure on publication and its stats/zscores
-- delete first
DROP TRIGGER IF EXISTS review_afterDelete_pubStatUpdate;
-- Trigger for updating publication and game stats on review insert
DELIMITER //
CREATE TRIGGER review_afterDelete_pubStatUpdate AFTER DELETE ON review
	FOR EACH ROW
    BEGIN
		CALL usp_one_pub_game_calcs(OLD.publication_publicationId);
	END//
DELIMITER ;


-- DONE
