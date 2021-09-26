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
-- FOR rec IN ( SELECT RecTime AS t, message AS m FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > timestampadd(day, -90, now()) )
-- DO INSERT IGNORE INTO `demay_farm`.`master_temp` SET time = rec.t, value = json_value(rec.m, '$.Temperature');
-- END FOR;
 /*[ end_label ]*/
INSERT IGNORE INTO  `demay_farm`.`master_temp` (SELECT RecTime AS t, json_value(message, '$.Temperature') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`master_hum` (SELECT RecTime AS t, json_value(message, '$.Humidity') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'cc50e3550d5b/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`computer_temp` (SELECT RecTime AS t, json_value(message, '$.Temperature') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'a020a613638e/data' AND RecTime > '2021-07-31 10:46:13');
INSERT IGNORE INTO  `demay_farm`.`computer_hum` (SELECT RecTime AS t, json_value(message, '$.Humidity') AS t FROM `demay_farm`.`mqttmessages` WHERE topic = 'a020a613638e/data' AND RecTime > '2021-07-31 10:46:13');
$$
DELIMITER ;

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
FOR rec IN ( SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), created) AS t, state FROM `new_ha`.`states` WHERE entity_id='binary_sensor.dining_motion' AND created > timestampadd(day, -90, now()) )
DO   CALL `demay_farm`.`add_pt_to_dining_motion`(rec.t, rec.state='on');
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

-- INSERT IGNORE INTO `demay_farm`.`computer_motion` (Time, Sensor, value)
--   SELECT RecTime, "Computer Room", json_value(message, '$.MotionDetected') = 'ON' FROM `demay_far,`.`mqttmessages`
--   WHERE topic = 'a020a613638e/data' AND SUBSTR(json_value(message, '$.PublishReason'),1,1) = 'M' ;

DELIMITER $$
CREATE OR REPLACE TRIGGER SaveInterestingMqtt AFTER INSERT ON `demay_farm`.`mqttmessages` 
FOR EACH ROW
`whole_proc`:
BEGIN
    /* Pressure Booster pump data.  */
    IF NEW.topic = 'dc4f220da30c/data' OR NEW.topic = 'e8db84e569cf/data' THEN
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
    {"MachineID":"e8db84e302d0","SampleTime":"2021-09-21 20:36:09-0700","MotionDetected":"ON","Temperature":84.38,"Humidity":13.9,"ConsolePower":"ON","PublishReason":"M---"}
    */
    IF NEW.topic = 'e8db84e302d0/data' THEN
        CALL  add_pt_to_kitchen2_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
END;
$$
DELIMITER ;
