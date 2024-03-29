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
/*    Stuff for 24Hr solar production table
CREATE TABLE `solar24Hr` (
  `Time` timestamp NOT NULL,
  `24HrWh` double DEFAULT NULL,
  PRIMARY KEY (`Time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*
 *  Trigger on solarinverter data to save interesting values to individual tables.
 *  For easier access for plotting.
 */
DELIMITER $$
CREATE OR REPLACE TRIGGER Update24HrWh AFTER INSERT ON `Steamboat`.`solarinverter_102`
FOR EACH ROW
BEGIN
  SELECT Time, wh INTO @prevTime, @prevWh FROM `Steamboat`.`solarinverter_102` WHERE Time > TIMESTAMPADD(MINUTE, -1443, NEW.Time) LIMIT 1;
  INSERT IGNORE INTO  `Steamboat`.`solar24Hr` SET Time = NEW.Time, 24HrWh = NEW.wh - @prevWh;
END;
$$
DELIMITER ;

/* Fill in solar24Hr table from history
 *//
DELIMITER $$
FOR rec IN ( SELECT Time AS t, wh AS wh FROM `Steamboat`.`solarinverter_102` WHERE Time > '2022-04-03' )
DO
  SELECT Time, wh INTO @prevTime, @prevWh FROM `Steamboat`.`solarinverter_102` WHERE Time > TIMESTAMPADD(MINUTE, -1443, rec.t) LIMIT 1;
  INSERT IGNORE INTO  `Steamboat`.`solar24Hr` SET Time = rec.t, 24HrWh = rec.wh - @prevWh;
END FOR;
$$
DELIMITER ;

---------------------------------------
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

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = 'cc50e3c70fc9/data' AND RecTime > timestampadd(day, -30, now()) )
DO
  CALL add_pt_to_furnace_fan(rec.t, json_value(rec.m, '$.Fan') = 'ON');
  CALL add_pt_to_furnace_burner(rec.t, json_value(rec.m, '$.Burner') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = 'dc4f225f31f6/data' AND RecTime > timestampadd(day, -10, now()) )
DO
  CALL add_pt_to_kitchen_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
  INSERT IGNORE INTO `steamboat`.`kitchen_temp` SET time = rec.t, value = json_value(rec.m, '$.Temperature');
  INSERT IGNORE INTO `steamboat`.`kitchen_hum` SET time = rec.t, value = json_value(rec.m, '$.Humidity');
  INSERT IGNORE INTO `steamboat`.`kitchen_light` SET time = rec.t, value = json_value(rec.m, '$.LightValue');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `steamboat`.`mqttmessages` WHERE topic = 'a020a6135ed9/data' AND RecTime > timestampadd(day, -22, now()) )
DO
  CALL add_pt_to_craft_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
  INSERT IGNORE INTO `steamboat`.`craft_temp` SET time = rec.t, value = json_value(rec.m, '$.Temperature');
  INSERT IGNORE INTO `steamboat`.`craft_hum` SET time = rec.t, value = json_value(rec.m, '$.Humidity');
  INSERT IGNORE INTO `steamboat`.`craft_light` SET time = rec.t, value = json_value(rec.m, '$.LightValue');
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

CREATE OR REPLACE FUNCTION IsNumeric (sIn varchar(1024)) RETURNS tinyint
RETURN sIn REGEXP '^(-|\\+){0,1}([0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+|[0-9]+)$';

CREATE OR REPLACE FUNCTION FloatVal (sIn varchar(1024)) RETURNS FLOAT
RETURN IF(IsNumeric(sIn), CAST(sIn AS FLOAT), NULL);


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
        CALL  add_pt_to_furnace_fan(NEW.rectime, json_value(NEW.message, '$.Fan') = 'ON');
        CALL  add_pt_to_furnace_burner(NEW.rectime, json_value(NEW.message, '$.Burner') = 'ON');
        INSERT IGNORE INTO `steamboat`.`garage_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `steamboat`.`garage_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
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
    /* Kitchen message example:   a020a6135ed9
    dc4f225f31f6/data {"MachineID":"dc4f225f31f6","SampleTime":"2021-11-17 13:59:41-0700","MotionDetected":"OFF","MotionVal":"   ",
      "Temperature":67.64,"Humidity":41.5,"ConsolePower":"ON","TodayMissingWxReports":4,"LightValue":913,"PublishReason":"-----"}
    */
    IF NEW.topic = 'dc4f225f31f6/data' OR New.topic = '441793118161/data' THEN
        CALL  add_pt_to_kitchen_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        INSERT IGNORE INTO `steamboat`.`kitchen_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `steamboat`.`kitchen_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
        INSERT IGNORE INTO `steamboat`.`kitchen_light` SET time = NEW.rectime, value = json_value(NEW.message, '$.LightValue');
        LEAVE `whole_proc`;
    END IF;
    /* Craft message example:
    a020a6135ed9/data {"MachineID":"a020a6135ed9","SampleTime":"2022-03-18 10:26:49-0600","MotionDetected":"OFF",
    "Temperature":59.72,"Humidity":30.2,"LightLevel":104,"PublishReason":"----"}
    */
    IF NEW.topic = 'a020a6135ed9/data' THEN
        CALL  add_pt_to_craft_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        INSERT IGNORE INTO `steamboat`.`craft_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `steamboat`.`craft_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
        INSERT IGNORE INTO `steamboat`.`craft_light` SET time = NEW.rectime, value = json_value(NEW.message, '$.LightValue');
        LEAVE `whole_proc`;
    END IF;
    /* HomeAssistant states message example
    haState/Temps/data { "utcTime": "2023-04-19 14:55:00.240945" , "dining_temp": 60.9 ,"living_temp": 63.2 ,"guest_temp": 61.6  ,"kitchen_temp": 62.7 ,"computer_temp": 66.02 }
    */
    IF NEW.topic = 'haState/Temps/data' THEN
        INSERT IGNORE INTO `steamboat`.`living_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_temp'));
        INSERT IGNORE INTO `steamboat`.`mud_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.mud_temp'));
        INSERT IGNORE INTO `steamboat`.`master_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.master_temp'));
        INSERT IGNORE INTO `steamboat`.`computer_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_temp'));
        LEAVE `whole_proc`;
    END IF;
    /* HomeAssistant states message example
    haState/Hums/data { "utcTime": "2023-04-19 14:55:00.257226" , "dining_hum": 21.0 ,"living_hum": 34.0 ,"guest_hum": 28.0 ,"kitchen_hum": 34.0 ,"computer_hum": 33 }
    */
    IF NEW.topic = 'haState/Hums/data' THEN
        INSERT IGNORE INTO `steamboat`.`living_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_hum'));
        INSERT IGNORE INTO `steamboat`.`master_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.master_hum'));
        INSERT IGNORE INTO `steamboat`.`mud_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.mud_hum'));
        INSERT IGNORE INTO `steamboat`.`computer_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_hum'));
        LEAVE `whole_proc`;
    END IF;
    /* HomeAssistant states message example
    haState/Powers/data { "utcTime": "2023-04-19 14:55:00.271107" , "fridge_power": 89.98 ,"humidifier_power": 0.0 ,"master_heater_power": 0.0 ,"kitchen_heater_power": 0.0 ,"living_heater_power": 0.0 ,"dining_heater_power": 0.0 ,"guest_heater_power": 0.0  ,"kitchen_heater_power": 0.0 ,"computer_heater_power": 0.0 }
    */
    IF NEW.topic = 'haState/Powers/data' THEN
        INSERT IGNORE INTO `steamboat`.`master_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.master_heater_power'));
        INSERT IGNORE INTO `steamboat`.`kitchen_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.kitchen_heater_power'));
        INSERT IGNORE INTO `steamboat`.`living_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_heater_power'));
        INSERT IGNORE INTO `steamboat`.`craft_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.craft_heater_power'));
        INSERT IGNORE INTO `steamboat`.`guest_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.guest_heater_power'));
        INSERT IGNORE INTO `steamboat`.`computer_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_heater_power'));
        LEAVE `whole_proc`;
    END IF;

/*
haState/Lights/data { "utcTime": "2023-05-08 18:10:00.126951" , "living_light": "63.0" , "mud_light": "0.0" , "master_light": "115.0" , "computer_light": "298.0" }
*/
    IF NEW.topic = 'haState/Lights/data' THEN
        INSERT IGNORE INTO `steamboat`.`master_light` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.master_light'));
        INSERT IGNORE INTO `steamboat`.`living_light` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_light'));
        INSERT IGNORE INTO `steamboat`.`mud_light` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.mud_light'));
        INSERT IGNORE INTO `steamboat`.`computer_light` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_light'));
        LEAVE `whole_proc`;
    END IF;

/*
haState/Uvs/data { "utcTime": "2023-05-08 18:10:00.135332" , "living_uv": "0.0" , "mud_uv": "0.0" , "master_uv": "0.0" , "computer_uv": "0.0" }
*/
    IF NEW.topic = 'haState/Uvs/data' THEN
        INSERT IGNORE INTO `steamboat`.`master_uv` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.master_uv'));
        INSERT IGNORE INTO `steamboat`.`living_uv` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_uv'));
        INSERT IGNORE INTO `steamboat`.`mud_uv` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.mud_uv'));
        INSERT IGNORE INTO `steamboat`.`computer_uv` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_uv'));
        LEAVE `whole_proc`;
    END IF;

    /* HomeAssistant states message example
    haState/Motions/data { "utcTime": "2023-04-19 14:55:00.285041" , "dining_motion": 0 ,"living_motion": 0 ,"guest_motion": 0 ,"kitchen_motion": 0 ,"computer_motion": 0 }
    */
    IF NEW.topic = 'haState/Motions/data' THEN
        CALL  add_pt_to_master_motion(NEW.rectime, json_value(NEW.message, '$.master_motion'));
        CALL  add_pt_to_living_motion(NEW.rectime, json_value(NEW.message, '$.living_motion'));
        CALL  add_pt_to_computer_motion(NEW.rectime, json_value(NEW.message, '$.computer_motion'));
        CALL  add_pt_to_mud_motion(NEW.rectime, json_value(NEW.message, '$.mud_motion'));
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

CREATE TABLE IF NOT EXISTS  `steamboat`.`craft_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`craft_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`craft_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`craft_motion` LIKE  `steamboat`.`BoolTableTemplate`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_light` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`computer_uv` LIKE  `steamboat`.`test`;

CREATE TABLE IF NOT EXISTS  `steamboat`.`computerW_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`masterW_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`guest_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`garage_temp` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`garage_hum` LIKE  `steamboat`.`test`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`garage_motion` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`furnace_fan` LIKE  `steamboat`.`BoolTableTemplate`;
CREATE TABLE IF NOT EXISTS  `steamboat`.`furnace_burner` LIKE  `steamboat`.`BoolTableTemplate`;

INSERT IGNORE INTO garage_temp SELECT RecTime AS time, json_value(message, '$.Temperature') AS value FROM `steamboat`.`mqttmessages` WHERE topic = 'cc50e3c70fc9/data' AND RecTime > timestampadd(day, -30, now());
INSERT IGNORE INTO garage_hum SELECT RecTime AS time, json_value(message, '$.Humidity') AS value FROM `steamboat`.`mqttmessages` WHERE topic = 'cc50e3c70fc9/data' AND RecTime > timestampadd(day, -30, now());
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
  INSERT IGNORE INTO `steamboat`.`master_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.masterbed_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`master_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.masterbed_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`master_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.masterbed_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_master_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.masterwindowtemperature' THEN
  INSERT IGNORE INTO `steamboat`.`master_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      LIVING ROOM SENSORS   */
 IF NEW.entity_id='sensor.livingroom_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`living_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.livingroom_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`living_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.livingroom_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`living_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.livingroom_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_living_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.livingroom_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`living_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      COMPUTER ROOM SENSORS   */
 IF NEW.entity_id='sensor.office_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`computer_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.office_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`computer_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.office_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`computer_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.office_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_computer_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.office_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`computer_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      KITCHEN SENSORS   */
 IF NEW.entity_id='sensor.kitchen_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.kitchen_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_kitchen_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), (NEW.state = 'on'));
  INSERT IGNORE INTO `steamboat`.`kitchen_motion` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=(NEW.state = 'on');
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*      MUD ROOM SENSORS   */
 IF NEW.entity_id='sensor.mudroom_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > -40 THEN
  INSERT IGNORE INTO `steamboat`.`mud_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.mudroom_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `steamboat`.`mud_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.mudroom_enviro_illuminance' THEN
  INSERT IGNORE INTO `steamboat`.`mud_light` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='binary_sensor.mudroom_enviro_home_security_motion_detection' THEN
  CALL  `steamboat`.`add_pt_to_mud_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), (NEW.state = 'on'));
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.mudroom_enviro_ultraviolet' THEN
  INSERT IGNORE INTO `steamboat`.`mud_uv` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

    /*     HEATERS   */
 IF NEW.entity_id='sensor.office_heater_power' AND NEW.state >= 0 THEN
  INSERT IGNORE INTO `steamboat`.`computer_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bed_heater_switch_power' AND NEW.state >= 0 THEN
  INSERT IGNORE INTO `steamboat`.`master_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_heater_switch_power' AND NEW.state >= 0 THEN
  INSERT IGNORE INTO `steamboat`.`guest_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_heater_power' AND NEW.state >= 0 THEN
  INSERT IGNORE INTO `steamboat`.`kitchen_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.craft_heater_power' AND NEW.state >= 0 THEN
  INSERT IGNORE INTO `steamboat`.`craft_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_heater_power' AND NEW.state >= 0 THEN
  INSERT IGNORE INTO `steamboat`.`living_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state, 1);
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
