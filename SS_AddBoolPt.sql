/*
 *  Call this procedure each time a new row of boolean data is added to the
 *  mqttmessages table.  It updates the motion table with extracted information.
 *
 *  The idea is to have two rows in the table for each change in the state of motion,
 *  the first having the time of the change, and the second having the time of the next
 *  change, and both having the duration of the state.  To make plotting the durations
 *  make a "square wave" with the height being the duration of each state.
 *
 *  Args:
 *    newTime: DATETIME(6)  The timestamp for the newly inserted data point.
 *    newval:  BOOLEAN      The value of the state of the motion (true if motion detected).
 *
 *  Session Vars created/used inside:
 *    @theId      The id of the last row in the pump_data table.
 *    @prevVal    The state of the pump in the last row in the pump_data table.
 *    @iDm1       The id of the second to last row in the pump_data table.
 *    @prevTm1    The time of the second to last row in the pump_data table.
 *
 *  Unused session Vars used inside:
 *    @iD         = @theId
 *    @prevT      The time of the last row in the pump_data table.
 *                  Gets updated every time a new point is added to mqttmessages.
 *    @prevValm1  The state of the pump in the second to last row in the pump_data table.
 *
 *  The duration column in the motion table is updated to reflect the duration that
 *  the motion has been in the same state.  When the motion state changes, two rows are added
 *  to the table with the time of the second advanced by one microsecond (to keep the rows
 *  in the same order whether sorted by time or id).  The duration of both added rows is
 *  zero, but will be updated when the next motion data comes in.
 *
 *  See comments below for table creation.
 */
DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_kitchen_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`kitchen_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`kitchen_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`kitchen_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`kitchen_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`kitchen_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`kitchen_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`kitchen_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`kitchen_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`kitchen_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_craft_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`craft_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`craft_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`craft_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`craft_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`craft_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`craft_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`craft_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`craft_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`craft_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_garage_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`garage_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`garage_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`garage_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`garage_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`garage_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`garage_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`garage_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`garage_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`garage_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_mud_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`mud_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`mud_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`mud_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`mud_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`mud_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`mud_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`mud_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`mud_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`mud_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_dining_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`dining_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`dining_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`dining_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`dining_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`dining_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`dining_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`dining_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`dining_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`dining_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_living_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`living_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`living_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`living_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`living_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`living_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`living_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`living_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`living_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`living_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_computer_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`computer_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`computer_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`computer_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`computer_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`computer_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`computer_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`computer_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`computer_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`computer_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_computerW_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`computerW_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`computerW_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`computerW_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`computerW_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`computerW_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`computerW_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`computerW_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`computerW_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`computerW_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_guest_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`guest_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`guest_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`guest_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`guest_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`guest_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`guest_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`guest_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`guest_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`guest_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_master_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`master_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`master_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`master_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`master_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`master_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`master_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`master_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`master_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`master_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_masterW_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`masterW_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`masterW_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`masterW_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`masterW_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`masterW_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`masterW_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`masterW_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`masterW_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`masterW_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_furnace_fan ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`furnace_fan`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`furnace_fan`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`furnace_fan` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`furnace_fan` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`furnace_fan` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`furnace_fan` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`furnace_fan` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`furnace_fan` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`furnace_fan` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_furnace_burner ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`furnace_burner`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`furnace_burner`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`furnace_burner` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`furnace_burner` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`furnace_burner` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`furnace_burner` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`furnace_burner` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`furnace_burner` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`furnace_burner` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Play ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `steamboat`.`play_data`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `steamboat`.`play_data`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`play_data` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `steamboat`.`play_data` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`play_data` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`play_data` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

/*

CREATE OR REPLACE TABLE `steamboat`.`BoolTableTemplate` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) DEFAULT NULL,
  `value` tinyint(1) DEFAULT NULL,
  `duration` float DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `steamboat`.`kitchen_motion` LIKE BoolTableTemplate;
CREATE TABLE `steamboat`.`dining_motion` LIKE BoolTableTemplate;
CREATE TABLE `steamboat`.`living_motion` LIKE BoolTableTemplate;
CREATE TABLE `steamboat`.`computer_motion` LIKE BoolTableTemplate;
CREATE TABLE `steamboat`.`guest_motion` LIKE BoolTableTemplate;
CREATE TABLE `steamboat`.`master_motion` LIKE BoolTableTemplate;


CREATE TABLE `steamboat`.`play_data` LIKE BoolTableTemplate;

CALL add_pt_to_Play('2021-06-04 10:30:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:31:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:32:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:33:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:34:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:35:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:36:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:37:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:38:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:39:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:45:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:46:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:47:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:48:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:52:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:53:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:54:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:55:00.123456', 1); SELECT * FROM play_data;

DROP TABLE IF EXISTS Play_data;

--*/

/*
This didn't work because for some reason "WHERE device = @newDev" clause is ignored.
DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Play2 ( newTime DATETIME(6), newval BOOLEAN, device VARCHAR(255)) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;
        SET @newDev = device;
        SET @iD = 0;
        SET @iDm1 = 0;

        SELECT IFNULL(Id, 0), Time, Value, device INTO @iD, @prevT, @prevVal, @prevDev FROM `steamboat`.`play_data` WHERE device = @newDev ORDER BY Id DESC LIMIT 1;
        SELECT IFNULL(Id, 0), Time, Value, device  INTO @iDm1, @prevTm1, @prevValm1, @prevDevm1
            FROM `steamboat`.`play_data`
            WHERE Id < @Id AND device = @newDev
            ORDER BY Id DESC LIMIT 1;
        select @iD, @prevT, @prevVal, @prevDev, @newDev;
        select @iDm1, @prevTm1, @prevValm1, @prevDevm1, @newDev;
        -- SELECT IFNULL(Id,0) INTO @theId FROM `steamboat`.`play_data` WHERE device = @newDev ORDER BY Id DESC LIMIT 1;
        -- SELECT IFNULL(Id,0) INTO @rowCount2 FROM `steamboat`.`play_data` WHERE device = @newDev AND ID < @rowCount;
        IF @iD = 0 THEN
            select "Inserting first row.";
            INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, @newT, @newDev, @newV, 0);
        ELSEIF @iDm1 = 0 THEN
            select "Inserting second row.";
            INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, @newT, @newDev, @newV, 0);
        -- SELECT count(device) INTO @rowCount FROM `steamboat`.`play_data` WHERE device = @newDev;
        -- SELECT count(device) AS RowCount, @newDev FROM `steamboat`.`play_data` WHERE device = @newDev;
        -- select CONCAT("Row count for ", @newDev, " is ", @rowCount);
        ELSE
            -- SELECT MAX(Id) INTO @theId FROM `steamboat`.`play_data` WHERE device = @newDev;
            -- SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `steamboat`.`play_data` WHERE Id = @theId LIMIT 1;
            -- SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1
            --   FROM `steamboat`.`play_data`
            --   WHERE Id < @theId AND device = @newDev
            --   ORDER BY Id DESC LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `steamboat`.`play_data` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @Id;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `steamboat`.`play_data` SET duration = @dur WHERE Id = @iD OR Id = @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, @newT, @newDev, @newV, 0);
                INSERT INTO `steamboat`.`play_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newDev, @newV, 0);
            END IF;
        END IF;
    END;
$$

DELIMITER ;

CREATE OR REPLACE TABLE `booltabletemplate2` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) DEFAULT NULL,
  `device` varchar(255) NOT NULL,
  `value` tinyint(1) DEFAULT NULL,
  `duration` float DEFAULT NULL,
  INDEX (device),
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE Play_data like BoolTableTemplate2;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:30:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:30:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:31:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:31:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:32:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:32:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:33:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:34:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:35:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:33:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:34:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:36:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:37:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:38:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:39:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:35:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:36:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:37:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:38:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:39:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:45:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:46:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:47:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:48:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:45:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:46:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:47:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:48:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:52:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:53:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:54:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:55:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:52:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:53:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:54:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:55:00.123456', 1, 'playDe2'); SELECT * FROM play_data;

DROP TABLE IF EXISTS Play_data;
*/
