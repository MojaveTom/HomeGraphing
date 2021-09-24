DELIMITER |
CREATE TABLE IF NOT EXISTS `steamboat`.`args`
(
    Id BIGINT AUTO_INCREMENT PRIMARY KEY, -- primary key column
    theId_max BIGINT,
    theId BIGINT,
    newT DATETIME(6),
    newV BOOLEAN,
    prevT DATETIME(6),
    prevVal BOOLEAN,
    iDm1 BIGINT,
    prevTm1 DATETIME(6),
    prevValm1 boolean
);
|

CREATE OR REPLACE PROCEDURE ShowArgs(newT DATETIME(6), newV BOOL)
BEGIN
    INSERT INTO args VALUES (DEFAULT, @theId, @iD, newT, newV, @prevT, @prevVal, @iDm1, @prevTm1, @prevValm1);
END;
|
DELIMITER ;

/*  Load motion tables from existing mqtt data.
*/
DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = 'cc50e3c704c5/data' AND RecTime > timestampadd(day, -90, now()) )
    DO CALL add_pt_to_guest_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = '3c71bf36ea05/data' AND RecTime > timestampadd(day, -30, now()) )
    DO CALL add_pt_to_computerW_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = 'cc50e3c70fc9/data' AND RecTime > timestampadd(day, -30, now()) )
    DO CALL add_pt_to_garage_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = '3c71bf36eb61/data' AND RecTime > timestampadd(day, -30, now()) )
DO CALL add_pt_to_masterW_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

/**********************  Load new motion tables from old.   *********************************/
RENAME TABLE mud_motion TO mud_motion_old;
CREATE TABLE mud_motion like BoolTableTemplate;
DELIMITER $$
FOR rec in ( SELECT Time, value FROM mud_motion_old WHERE Time > TIMESTAMPADD(day, -30, now()) )
    DO CALL add_pt_to_mud_motion(rec.Time, rec.value);
END FOR;
$$
DELIMITER ;

RENAME TABLE computer_motion TO computer_motion_old;
CREATE TABLE computer_motion like BoolTableTemplate;
DELIMITER $$
FOR rec in ( SELECT Time, value FROM computer_motion_old WHERE Time > TIMESTAMPADD(day, -30, now()) )
    DO CALL add_pt_to_computer_motion(rec.Time, rec.value);
END FOR;
$$
DELIMITER ;

RENAME TABLE living_motion TO living_motion_old;
CREATE TABLE living_motion like BoolTableTemplate;
DELIMITER $$
FOR rec in ( SELECT Time, value FROM living_motion_old WHERE Time > TIMESTAMPADD(day, -30, now()) )
    DO CALL add_pt_to_living_motion(rec.Time, rec.value);
END FOR;
$$
DELIMITER ;

RENAME TABLE master_motion TO master_motion_old;
CREATE TABLE master_motion like BoolTableTemplate;
DELIMITER $$
FOR rec in ( SELECT Time, value FROM master_motion_old WHERE Time > TIMESTAMPADD(day, -30, now()) )
    DO CALL add_pt_to_master_motion(rec.Time, rec.value);
END FOR;
$$
DELIMITER ;

/**************  Create when `steamboat` is the active database.  ***************************/
DELIMITER $$
CREATE OR REPLACE TRIGGER SaveInterestingMqtt AFTER INSERT ON `steamboat`.`mqttmessages` 
FOR EACH ROW
`whole_proc`:
BEGIN
    /* Computer Window MTHL: message example
    {"MachineID":"3c71bf36ea05","UnixTime":1632418224,"SampleTime":"2021-09-23 11:30:24-0600","MotionDetected":"ON","Temperature":61.5,"Humidity":51,"LightLevel":341,"PublishReason":"---L"}
    */
    IF NEW.topic = '3c71bf36ea05/data' THEN
        CALL  add_pt_to_computerW_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
    /* Furnace sensors: message example
    {"MachineID":"cc50e3c70fc9","UnixTime":1632415247,"SampleTime":"2021-09-23 10:40:47-0600","MotionDetected":"OFF","Burner":"OFF","Fan":"OFF","Temperature":69.3,"Humidity":26.5,"PublishReason":"-----"}
    */
    IF NEW.topic = 'cc50e3c70fc9/data' THEN
        CALL  add_pt_to_garage_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
    /* Master window: message example
    {"MachineID":"3c71bf36eb61","UnixTime":1632417688,"SampleTime":"2021-09-23 11:21:28-0600","MotionDetected":"OFF","Temperature":91.2,"Humidity":28.3,"LightLevel":969,"PublishReason":"---L"}
    */
    IF NEW.topic = '3c71bf36eb61/data' THEN
        CALL  add_pt_to_masterW_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
    /* Guest: message example
    {"MachineID":"cc50e3c704c5","UnixTime":1632417115,"SampleTime":"2021-09-23 11:11:55-0600","MotionDetected":"OFF","Temperature":68.2,"Humidity":44.3,"PublishReason":"---"}
    */
    IF NEW.topic = 'cc50e3c704c5/data' THEN
        CALL  add_pt_to_guest_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
END;
$$
DELIMITER ;


/* Steamboat tables */

/*************************************  CREATE TABLES FOR INTERESTING `homeassistant`.`states`    *************************************/
CREATE TABLE IF NOT EXISTS  `steamboat`.`test` (
  `time` timestamp(6) NOT NULL DEFAULT current_timestamp(6),
  `value` float DEFAULT NULL,
  PRIMARY KEY (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS  `steamboat`.`master_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`master_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`master_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`master_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`master_uv` LIKE  `steamboat`.`test`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`living_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`living_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`living_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`living_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`living_uv` LIKE  `steamboat`.`test`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`mud_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`mud_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`mud_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`mud_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`mud_uv` LIKE  `steamboat`.`test`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`kitchen_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`kitchen_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`kitchen_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`kitchen_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`kitchen_uv` LIKE  `steamboat`.`test`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_uv` LIKE  `steamboat`.`test`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`computerW_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`masterW_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`guest_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`garage_motion` LIKE  `steamboat`.`BoolTableTemplate`;


/*
  Steamboat weather as retrieved from Ambient Weather (.net) for my weather station.
*/
CREATE TABLE IF NOT EXISTS `steamboat`.`weather` (
  `dateutc` BIGINT
, `tempinf` FLOAT
, `tempf` FLOAT
, `humidityin` FLOAT
, `humidity` FLOAT
, `windspeedmph` FLOAT
, `windgustmph` FLOAT
, `maxdailygust` FLOAT
, `winddir` FLOAT
, `baromabsin` FLOAT
, `baromrelin` FLOAT
, `hourlyrainin` FLOAT
, `dailyrainin` FLOAT
, `weeklyrainin` FLOAT
, `monthlyrainin` FLOAT
, `yearlyrainin` FLOAT
, `solarradiation` FLOAT
, `uv` FLOAT
, `feelsLike` FLOAT
, `dewPoint` FLOAT
, `lastRain` TIMESTAMP(6) NULL DEFAULT NULL
, `date`  TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
, PRIMARY KEY (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


/***********************************************************************************************************************************

        homeassistant      database

***************************************  CREATE TRIGGER TO POPULATE INTERESTING STATE TABLES  ************************************/
/* Create when `homeassistant` is the current database.  */
DELIMITER //
CREATE OR REPLACE TRIGGER save_interesting_states
AFTER INSERT ON `homeassistant`.`states`
FOR EACH ROW
`whole_proc`:
BEGIN
    
    /*      MASTER BEDROOM SENSORS   */
 IF NEW.entity_id='sensor.masterbed_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`master_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.masterbed_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`master_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.masterbed_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`master_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.masterbed_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_master_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.masterwindowtemperature' THEN
  INSERT IGNORE INTO `steamboat`.`master_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      LIVING ROOM SENSORS   */
 IF NEW.entity_id='sensor.livingroom_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`living_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.livingroom_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`living_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.livingroom_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`living_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.livingroom_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_living_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.livingroom_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`living_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      COMPUTER ROOM SENSORS   */
 IF NEW.entity_id='sensor.office_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`computer_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.office_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`computer_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.office_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`computer_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.office_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_computer_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.office_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`computer_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      KITCHEN SENSORS   */
 IF NEW.entity_id='sensor.kitchen_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.kitchen_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_kitchen_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), (NEW.state = 'on'));
  INSERT IGNORE INTO `steamboat`.`kitchen_motion` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=(NEW.state = 'on');
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      MUD ROOM SENSORS   */
 IF NEW.entity_id='sensor.mudroom_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`mud_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.mudroom_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`mud_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.mudroom_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`mud_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.mudroom_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_mud_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.mudroom_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`mud_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

END; //

DELIMITER ;

/***************************************  COPY OLD INTERESTING STATES TO INDIVIDUAL STATE TABLES  ***********************************/
INSERT IGNORE INTO `steamboat`.`master_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > -40
    AND `homeassistant`.`states`.`created` > '2019-01-13';
*/
INSERT IGNORE INTO `steamboat`.`master_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`master_light` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_light'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`master_motion` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 0) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_motion_kind'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`master_uv` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_uv'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`living_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > -40
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`living_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`living_light` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_light'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`living_motion` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 0) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_motion_kind'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`living_uv` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_uv'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`computer_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.computer_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > -40
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`computer_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.computer_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`computer_light` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.computer_light'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`computer_motion` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 0) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.computer_motion_kind'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`computer_uv` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.computer_uv'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`kitchen_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > -40
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`kitchen_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`kitchen_light` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_light'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`kitchen_motion` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 0) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_motion_kind'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`kitchen_uv` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_uv'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`mud_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.mud_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > -40
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`mud_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.mud_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`mud_light` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.mud_light'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`mud_motion` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 0) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.mud_motion_kind'
    AND `homeassistant`.`states`.`created` > '2019-01-13';

INSERT IGNORE INTO `steamboat`.`mud_uv` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.mud_uv'
    AND `homeassistant`.`states`.`created` > '2019-01-13';
