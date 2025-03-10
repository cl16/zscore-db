-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema zscores
-- -----------------------------------------------------

-- -----------------------------------------------------
-- Schema zscores
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `zscores` DEFAULT CHARACTER SET utf8 ;
USE `zscores` ;

-- -----------------------------------------------------
-- Table `zscores`.`game`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `zscores`.`game` (
  `game_id` INT NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`game_id`),
  UNIQUE INDEX `game_id_UNIQUE` (`game_id` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `zscores`.`publication`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `zscores`.`publication` (
  `pub_id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `score_avg` DECIMAL(5,2) NULL,
  CHECK (`score_avg` >= 0 AND `score_avg` <= 100),
  `score_stddev` DECIMAL(4,2) NULL,
  CHECK (`score_stddev` >= 0),
  PRIMARY KEY (`pub_id`),
  UNIQUE INDEX `pub_id_UNIQUE` (`pub_id` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `zscores`.`review`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `zscores`.`review` (
  `game_id` INT NOT NULL,
  `pub_id` INT NOT NULL,
  `date` DATETIME NULL,
  `score` INT NOT NULL,
  CHECK (`score` >= 0 AND `score` <= 100),
  PRIMARY KEY (`game_id`, `pub_id`),
  INDEX `fk_score_publication1_idx` (`pub_id` ASC) VISIBLE,
  CONSTRAINT `fk_score_game`
    FOREIGN KEY (`game_id`)
    REFERENCES `zscores`.`game` (`game_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_score_publication1`
    FOREIGN KEY (`pub_id`)
    REFERENCES `zscores`.`publication` (`pub_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `zscores`.`stat`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `zscores`.`stat` (
  `game_id` INT NOT NULL,
  `pub_id` INT NOT NULL,
  `zscore` DECIMAL(4,3) NULL,
  PRIMARY KEY (`game_id`, `pub_id`),
  CONSTRAINT `fk_stat_gamePublication`
    FOREIGN KEY (`game_id`, `pub_id`)
    REFERENCES `zscores`.`review` (`game_id`, `pub_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
