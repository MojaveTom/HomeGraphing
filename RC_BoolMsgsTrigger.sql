DELIMITER |
CREATE TABLE IF NOT EXISTS `demay_farm`.`args`
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

DELIMITER $$
CREATE TABLE IF NOT EXISTS `demay_farm`.`driveway_alarms` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
$$
DELIMITER ;

DELIMITER $$
CREATE TABLE IF NOT EXISTS `demay_farm`.`gate_angle` (
  `Time` datetime(6) NOT NULL,
  `value` FLOAT DEFAULT NULL,
  PRIMARY KEY (`Time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
$$
DELIMITER ;

DELIMITER $$
CREATE TABLE IF NOT EXISTS `demay_farm`.`gate_battery` (
  `Time` datetime(6) NOT NULL,
  `value` FLOAT DEFAULT NULL,
  PRIMARY KEY (`Time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `demay_farm`.`mqttmessages` WHERE topic = 'a020a613638e/data' AND RecTime > timestampadd(day, -90, now()) )
DO CALL add_pt_to_computer_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > timestampadd(day, -90, now()) )
DO CALL add_pt_to_master_motion(rec.t, json_value(rec.m, '$.MotionDetected') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `demay_farm`.`mqttmessages` WHERE topic = 'e8db84e569cf/data' AND RecTime > '2022-04-03 19:20:55' )
DO CALL add_pt_to_gate_open(rec.t, json_value(rec.m, '$.GateOpen') = 'ON');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
FOR rec IN ( SELECT Time AS t, wh AS wh FROM `demay_farm`.`solarinverter_102` WHERE Time > '2022-04-03' )
DO
  SELECT Time, wh INTO @prevTime, @prevWh FROM `demay_farm`.`solarinverter_102` WHERE Time > TIMESTAMPADD(MINUTE, -1443, rec.t) LIMIT 1;
  INSERT IGNORE INTO  `demay_farm`.`solar24Hr` SET Time = rec.t, 24HrWh = rec.wh - @prevWh;
END FOR;
$$
DELIMITER ;


-- DELIMITER $$
/*[begin_label:]*/
-- FOR rec IN ( SELECT RecTime AS t, message AS m FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > timestampadd(day, -90, now()) )
-- DO INSERT IGNORE INTO `demay_farm`.`master_temp` SET time = rec.t, value = json_value(rec.m, '$.Temperature');
-- END FOR;
 /*[ end_label ]*/
INSERT IGNORE INTO  `demay_farm`.`master_temp` (SELECT RecTime AS t, json_value(message, '$.Temperature') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`master_hum` (SELECT RecTime AS t, json_value(message, '$.Humidity') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`computer_temp` (SELECT RecTime AS t, json_value(message, '$.Temperature') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'a020a613638e/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`computer_hum` (SELECT RecTime AS t, json_value(message, '$.Humidity') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'a020a613638e/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`kitchenMTH_temp` (SELECT RecTime AS t, json_value(message, '$.Temperature') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'e8db84e302d0/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`kitchenMTH_hum` (SELECT RecTime AS t, json_value(message, '$.Humidity') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'e8db84e302d0/data' AND RecTime > '2021-07-31 10:46:13');
$$
DELIMITER ;
INSERT IGNORE INTO  `demay_farm`.`gate_angle` (SELECT RecTime AS t, json_value(message, '$.GateAngle') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'e8db84e569cf/data' AND RecTime > '2021-10-31');
INSERT IGNORE INTO  `demay_farm`.`gate_battery` (SELECT RecTime AS t, json_value(message, '$.BatteryVolts') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'e8db84e569cf/data' AND RecTime > '2021-10-31');

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), created) AS t, state FROM `new_ha`.`states` WHERE entity_id='binary_sensor.kitchen_motion' AND created > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_kitchen_motion`(rec.t, rec.state='on');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), created) AS t, state FROM `new_ha`.`states` WHERE entity_id='binary_sensor.living_motion' AND created > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_living_motion`(rec.t, rec.state='on');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), created) AS t, state FROM `new_ha`.`states` WHERE entity_id='binary_sensor.guest_motion' AND created > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_guest_motion`(rec.t, rec.state='on');
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

INSERT IGNORE INTO `demay_farm`.`thermostat_temp` (Time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), last_updated), round(state) FROM `new_ha`.`states`
  WHERE entity_id='sensor.thermostat_temperature'  AND last_updated > timestampadd(day, -90, now());

INSERT IGNORE INTO `demay_farm`.`thermostat_hum` (Time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), last_updated), round(state) FROM `new_ha`.`states`
  WHERE entity_id='sensor.thermostat_humidity'  AND last_updated > timestampadd(day, -90, now());

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, JSON_VALUE(message, '$.dining_motion') as value FROM `demay_farm`.`mqttmessages` WHERE topic='haState/Motions/data' AND RecTime > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_dining_motion`(rec.t, rec.value);
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, JSON_VALUE(message, '$.living_motion') as value FROM `demay_farm`.`mqttmessages` WHERE topic='haState/Motions/data' AND RecTime > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_living_motion`(rec.t, rec.value);
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, JSON_VALUE(message, '$.guest_motion') as value FROM `demay_farm`.`mqttmessages` WHERE topic='haState/Motions/data' AND RecTime > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_guest_motion`(rec.t, rec.value);
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

DELIMITER $$
/*[begin_label:]*/
FOR rec IN ( SELECT RecTime AS t, JSON_VALUE(message, '$.dining_motion') as value FROM `demay_farm`.`mqttmessages` WHERE topic='haState/Temps/data' AND RecTime > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_dining_motion`(rec.t, rec.value);
END FOR;
 /*[ end_label ]*/
$$
DELIMITER ;

INSERT IGNORE INTO  `demay_farm`.`dining_temp` (SELECT RecTime AS t, json_value(message, '$.dining_temp') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Temps/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`living_temp` (SELECT RecTime AS t, json_value(message, '$.living_temp') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Temps/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`guest_temp` (SELECT RecTime AS t, json_value(message, '$.guest_temp') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Temps/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`kitchen_temp` (SELECT RecTime AS t, json_value(message, '$.kitchen_temp') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Temps/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`computer_temp` (SELECT RecTime AS t, json_value(message, '$.computer_temp') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Temps/data' AND RecTime > '2023-04-07 10:50:53');



INSERT IGNORE INTO  `demay_farm`.`dining_hum` (SELECT RecTime AS t, json_value(message, '$.dining_hum') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Hums/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`living_hum` (SELECT RecTime AS t, json_value(message, '$.living_hum') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Hums/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`guest_hum` (SELECT RecTime AS t, json_value(message, '$.guest_hum') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Hums/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`kitchen_hum` (SELECT RecTime AS t, json_value(message, '$.kitchen_hum') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Hums/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`computer_hum` (SELECT RecTime AS t, json_value(message, '$.computer_hum') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Hums/data' AND RecTime > '2023-04-07 10:50:53');


INSERT IGNORE INTO  `demay_farm`.`fridge_power` (SELECT RecTime AS t, json_value(message, '$.fridge_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`humidifier_power` (SELECT RecTime AS t, json_value(message, '$.humidifier_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`master_heater_power` (SELECT RecTime AS t, json_value(message, '$.master_heater_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`kitchen_heater_power` (SELECT RecTime AS t, json_value(message, '$.kitchen_heater_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`living_heater_power` (SELECT RecTime AS t, json_value(message, '$.living_heater_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`dining_heater_power` (SELECT RecTime AS t, json_value(message, '$.dining_heater_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`guest_heater_power` (SELECT RecTime AS t, json_value(message, '$.guest_heater_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');

INSERT IGNORE INTO  `demay_farm`.`computer_heater_power` (SELECT RecTime AS t, json_value(message, '$.computer_heater_power') AS v FROM `demay_farm`.`mqttmessages` WHERE topic = 'haState/Powers/data' AND RecTime > '2023-04-07 10:50:53');


/*
 *  Trigger on solarinverter data to save interesting values to individual tables.
 *  For easier access for plotting.
*/
DELIMITER $$
CREATE OR REPLACE TRIGGER Update24HrWh AFTER INSERT ON `demay_farm`.`solarinverter_102`
FOR EACH ROW
BEGIN
    /* Pressure Booster pump data.  */
  SELECT Time, wh INTO @prevTime, @prevWh FROM `demay_farm`.`solarinverter_102` WHERE Time > TIMESTAMPADD(MINUTE, -1443, NEW.Time) LIMIT 1;
  INSERT IGNORE INTO  `demay_farm`.`solar24Hr` SET Time = NEW.Time, 24HrWh = NEW.wh - @prevWh;
END;
$$
DELIMITER ;

-- INSERT IGNORE INTO `demay_farm`.`computer_motion` (Time, Sensor, value)
--   SELECT RecTime, "Computer Room", json_value(message, '$.MotionDetected') = 'ON' FROM `demay_far,`.`mqttmessages`
--   WHERE topic = 'a020a613638e/data' AND SUBSTR(json_value(message, '$.PublishReason'),1,1) = 'M' ;

CREATE OR REPLACE FUNCTION IsNumeric (sIn varchar(1024)) RETURNS tinyint
RETURN sIn REGEXP '^(-|\\+){0,1}([0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+|[0-9]+)$';

CREATE OR REPLACE FUNCTION FloatVal (sIn varchar(1024)) RETURNS FLOAT
RETURN IF(IsNumeric(sIn), CAST(sIn AS FLOAT), NULL);

/*
 *  Trigger on mqttmessages to save interesting values to individual tables.
 *  For easier access for plotting.
*/
DELIMITER $$
CREATE OR REPLACE TRIGGER SaveInterestingMqtt AFTER INSERT ON `demay_farm`.`mqttmessages`
FOR EACH ROW
`whole_proc`:
BEGIN
    /* Pressure Booster pump data.  */
    IF NEW.topic = 'dc4f220da30c/data' THEN
        CALL add_pt_to_Pump(NEW.rectime, (json_value(NEW.message, '$.PumpRun') = 'ON') );
        LEAVE `whole_proc`;
    END IF;
    /* Submersible and Pressure pump data.  */
    IF NEW.topic = 'a020a61228ea/data' THEN
        CALL add_pt_to_PressurePump(NEW.rectime, (json_value(NEW.message, '$.PressurePump') = 'ON') );
        CALL add_pt_to_SubmersiblePump(NEW.rectime, (json_value(NEW.message, '$.SubmersiblePump') = 'ON') );
        LEAVE `whole_proc`;
    END IF;
    /* Driveway Alarm data.  */
    IF NEW.topic = 'b827eb25526d/Driveway' /*AND (json_value(NEW.message, '$.AlarmState') = 'ON')*/ THEN
        INSERT INTO `demay_farm`.`driveway_alarms` VALUES (DEFAULT, json_value(NEW.message, '$.AlarmTime'), json_value(NEW.message, '$.AlarmState'));
        LEAVE `whole_proc`;
    END IF;
    /* Computer Room MTH: message example
    {"MachineID":"a020a613638e","SampleTime":"2021-09-15 21:18:43-0700","MotionDetected":"OFF","Temperature":84.92,"Humidity":24.9,"PublishReason":"M--"}
    */
    IF NEW.topic = 'a020a613638e/data' THEN
        CALL  add_pt_to_computer_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        INSERT IGNORE INTO `demay_farm`.`computer_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `demay_farm`.`computer_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
        LEAVE `whole_proc`;
    END IF;
    /* Master Bed MTH: message example
    {"MachineID":"cc50e3550d5b","UnixTime":1631768050,"SampleTime":"2021-09-15 21:54:10-0700","MotionDetected":"ON","Temperature":80.2,"Humidity":25.4,"PublishReason":"M--"}
    */
    IF NEW.topic = 'cc50e3550d5b/data' THEN
        CALL  add_pt_to_master_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        INSERT IGNORE INTO `demay_farm`.`master_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `demay_farm`.`master_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
        LEAVE `whole_proc`;
    END IF;
    /* Kitchen2 mthWeather: message example
     {"MachineID":"441793118161","SampleTime":"2023-01-31 14:57:16-0800","MotionDetected":"OFF","MotionVal":"----","Temperature":67.46,"Humidity":34.4,"ConsolePower":"ON","TodayMissingWxReports":0,"LightValue":976,"PublishReason":"M----"}
    */
    IF NEW.topic = '441793118161/data' THEN
        CALL  add_pt_to_kitchenMTH_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        INSERT IGNORE INTO `demay_farm`.`kitchenMTH_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `demay_farm`.`kitchenMTH_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
        LEAVE `whole_proc`;
    END IF;
    /* Gate data.
    {"MachineID":"e8db84e569cf","SampleTime":"2021-11-20 08:24:24-0800","GateOpen":false,"GateAngle":1.098096,"BatteryVolts":12.9639,"PublishReason":"----","RawX":462,"RawY":-296,"RawZ":-335,"GateOperate":false}
      */
    IF NEW.topic = 'e8db84e569cf/data' THEN
        CALL  add_pt_to_gate_open(NEW.rectime, json_value(NEW.message, '$.GateOpen') = 'ON');
        INSERT IGNORE INTO `demay_farm`.`gate_angle` SET time = NEW.RecTime, value = json_value(NEW.message, '$.GateAngle');
        INSERT IGNORE INTO `demay_farm`.`gate_battery` SET time = NEW.RecTime, value = json_value(NEW.message, '$.BatteryVolts');
        LEAVE `whole_proc`;
    END IF;

    /* HomeAssistant states message example
    haState/Temps/data { "utcTime": "2023-04-19 14:55:00.240945" , "dining_temp": 60.9 ,"living_temp": 63.2 ,"guest_temp": 61.6  ,"kitchen_temp": 62.7 ,"computer_temp": 66.02 }
    */
    IF NEW.topic = 'haState/Temps/data' THEN
        INSERT IGNORE INTO `demay_farm`.`dining_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.dining_temp')) ;
        INSERT IGNORE INTO `demay_farm`.`living_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_temp'));
        INSERT IGNORE INTO `demay_farm`.`guest_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.guest_temp'));
        INSERT IGNORE INTO `demay_farm`.`kitchen_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.kitchen_temp'));
        INSERT IGNORE INTO `demay_farm`.`computer_temp` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_temp'));
        LEAVE `whole_proc`;
    END IF;
    /* HomeAssistant states message example
    haState/Hums/data { "utcTime": "2023-04-19 14:55:00.257226" , "dining_hum": 21.0 ,"living_hum": 34.0 ,"guest_hum": 28.0 ,"kitchen_hum": 34.0 ,"computer_hum": 33 }
    */
    IF NEW.topic = 'haState/Hums/data' THEN
        INSERT IGNORE INTO `demay_farm`.`dining_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.dining_hum'));
        INSERT IGNORE INTO `demay_farm`.`living_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_hum'));
        INSERT IGNORE INTO `demay_farm`.`guest_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.guest_hum'));
        INSERT IGNORE INTO `demay_farm`.`kitchen_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.kitchen_hum'));
        INSERT IGNORE INTO `demay_farm`.`computer_hum` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_hum'));
        LEAVE `whole_proc`;
    END IF;
    /* HomeAssistant states message example
    haState/Powers/data { "utcTime": "2023-04-19 14:55:00.271107" , "fridge_power": 89.98 ,"humidifier_power": 0.0 ,"master_heater_power": 0.0 ,"kitchen_heater_power": 0.0 ,"living_heater_power": 0.0 ,"dining_heater_power": 0.0 ,"guest_heater_power": 0.0  ,"kitchen_heater_power": 0.0 ,"computer_heater_power": 0.0 }
    */
    IF NEW.topic = 'haState/Powers/data' THEN
        INSERT IGNORE INTO `demay_farm`.`fridge_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.fridge_power'));
        INSERT IGNORE INTO `demay_farm`.`humidifier_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.humidifier_power'));
        INSERT IGNORE INTO `demay_farm`.`master_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.master_heater_power'));
        INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.kitchen_heater_power'));
        INSERT IGNORE INTO `demay_farm`.`living_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.living_heater_power'));
        INSERT IGNORE INTO `demay_farm`.`dining_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.dining_heater_power'));
        INSERT IGNORE INTO `demay_farm`.`guest_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.guest_heater_power'));
        INSERT IGNORE INTO `demay_farm`.`computer_heater_power` SET time = NEW.rectime, value = FloatVal(json_value(NEW.message, '$.computer_heater_power'));
        LEAVE `whole_proc`;
    END IF;
    /* HomeAssistant states message example
    haState/Motions/data { "utcTime": "2023-04-19 14:55:00.285041" , "dining_motion": 0 ,"living_motion": 0 ,"guest_motion": 0 ,"kitchen_motion": 0 ,"computer_motion": 0 }
    */
    IF NEW.topic = 'haState/Motions/data' THEN
        CALL  add_pt_to_dining_motion(NEW.rectime, json_value(NEW.message, '$.dining_motion'));
        CALL  add_pt_to_living_motion(NEW.rectime, json_value(NEW.message, '$.living_motion'));
        CALL  add_pt_to_guest_motion(NEW.rectime, json_value(NEW.message, '$.guest_motion'));
        CALL  add_pt_to_kitchen_motion(NEW.rectime, json_value(NEW.message, '$.kitchen_motion'));
        LEAVE `whole_proc`;
    END IF;
END;
$$
DELIMITER ;

/*********************************************************************************
 *  Trigger in new_ha database to save interesting states to demay_farm tables;
 */
DELIMITER $$

CREATE OR REPLACE TRIGGER save_interesting_states
AFTER INSERT ON `new_ha`.`states`
FOR EACH ROW
`whole_proc`:
BEGIN
--  IF NEW.entity_id='sensor.dining_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
--   INSERT IGNORE INTO `demay_farm`.`dining_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;
--  IF NEW.entity_id='sensor.guest_bed_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
--   INSERT IGNORE INTO `demay_farm`.`guest_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;
--  IF NEW.entity_id='sensor.kitchen_enviro_air_temperature_3' AND NEW.state < 140 AND NEW.state > 20 THEN
--   INSERT IGNORE INTO `demay_farm`.`kitchen_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;
 IF NEW.entity_id='sensor.master_bedroom_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`master_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
--  IF NEW.entity_id='sensor.living_room_enviro_air_temperature_2' AND NEW.state < 140 AND NEW.state > 20 THEN
--   INSERT IGNORE INTO `demay_farm`.`living_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;

 IF NEW.entity_id='sensor.thermostat_temperature' AND NEW.state NOT LIKE 'unknown' AND NEW.state > 0 THEN
  INSERT IGNORE INTO `demay_farm`.`thermostat_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.thermostat_humidity' AND NEW.state NOT LIKE 'unknown' AND NEW.state > 0 THEN
  INSERT IGNORE INTO `demay_farm`.`thermostat_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=round(NEW.state);
  LEAVE `whole_proc`;
 END IF;

--  IF NEW.state NOT LIKE 'unknown' AND NEW.entity_id='climate.thermostat' THEN
--   INSERT IGNORE INTO `demay_farm`.`ac_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_updated), value=if(json_value(NEW.attributes,'$.hvac_action')='idle',0.0, if(json_value(NEW.attributes,'$.equipment_running')='compCool1,fan',2100.0, 0.0));
--   LEAVE `whole_proc`;
--  END IF;

--  IF NEW.entity_id='sensor.dining_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
--   INSERT IGNORE INTO `demay_farm`.`dining_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;
--  IF NEW.entity_id='sensor.guest_bed_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
--   INSERT IGNORE INTO `demay_farm`.`guest_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;
--  IF NEW.entity_id='sensor.kitchen_enviro_humidity_3' AND NEW.state < 110 AND NEW.state > -10 THEN
--   INSERT IGNORE INTO `demay_farm`.`kitchen_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;
 IF NEW.entity_id='sensor.master_bedroom_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`master_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
--  IF NEW.entity_id='sensor.living_room_enviro_humidity_2' AND NEW.state < 110 AND NEW.state > -10 THEN
--   INSERT IGNORE INTO `demay_farm`.`living_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
--   LEAVE `whole_proc`;
--  END IF;

 IF NEW.entity_id='sensor.computer_room_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`computer_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.dining_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_heater_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bed_heater_switch_electric_consumed_w' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`master_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_heater_electric_consumed_w_4' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`living_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.humidifier_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`humidifier_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF (NEW.entity_id='sensor.refrigerator_electric_consumed_w' AND NEW.state < 5000) OR (NEW.entity_id='sensor.fridge_power_w' AND NEW.state < 5000) THEN
  INSERT IGNORE INTO `demay_farm`.`fridge_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='switch.livingroom' THEN
  INSERT IGNORE INTO `demay_farm`.`lrlight_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=if(NEW.state='on', 100.0, 0.0);
  LEAVE `whole_proc`;
 END IF;


 IF NEW.entity_id='binary_sensor.living_motion' THEN
  CALL `demay_farm`.`add_pt_to_living_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.dining_motion' THEN
  CALL `demay_farm`.`add_pt_to_dining_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.kitchen_motion' THEN
  CALL `demay_farm`.`add_pt_to_kitchen_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.guest_motion' THEN
  CALL `demay_farm`.`add_pt_to_guest_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;

END;
$$
DELIMITER ;


/*********************************************************************************
 *  Trigger in current database to save interesting states to demay_farm tables;
 */
DELIMITER $$

CREATE OR REPLACE TRIGGER save_interesting_states
AFTER INSERT ON `states`
FOR EACH ROW
`whole_proc`:
BEGIN
 IF NEW.entity_id='sensor.dining_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_bed_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_air_temperature_3' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bedroom_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`master_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_enviro_air_temperature_2' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`living_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.state NOT LIKE 'unknown' AND NEW.entity_id='climate.thermostat' THEN
  INSERT IGNORE INTO `demay_farm`.`thermostat_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(json_value(NEW.attributes,'$.current_temperature'));
  INSERT IGNORE INTO `demay_farm`.`thermostat_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(json_value(NEW.attributes,'$.current_humidity'));
  INSERT IGNORE INTO `demay_farm`.`ac_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=if(json_value(NEW.attributes,'$.hvac_action')='idle',0.0, if(json_value(NEW.attributes,'$.equipment_running')='compCool1,fan',2100.0, 100.0));
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.dining_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_bed_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_humidity_3' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bedroom_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`master_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_enviro_humidity_2' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`living_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.computer_room_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`computer_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.dining_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_heater_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bed_heater_switch_electric_consumed_w' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`master_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_heater_electric_consumed_w_4' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`living_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.humidifier_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`humidifier_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF (NEW.entity_id='sensor.refrigerator_electric_consumed_w' AND NEW.state < 5000) OR (NEW.entity_id='sensor.fridge_power_w' AND NEW.state < 5000) THEN
  INSERT IGNORE INTO `demay_farm`.`fridge_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='switch.livingroom' THEN
  INSERT IGNORE INTO `demay_farm`.`lrlight_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), value=if(NEW.state='on', 100.0, 0.0);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='binary_sensor.living_motion' THEN
  CALL `demay_farm`.`add_pt_to_living_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.dining_motion' THEN
  CALL `demay_farm`.`add_pt_to_dining_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.kitchen_motion' THEN
  CALL `demay_farm`.`add_pt_to_kitchen_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.guest_motion' THEN
  CALL `demay_farm`.`add_pt_to_guest_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.last_changed), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;

END;
$$
DELIMITER ;
