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
FOR rec IN ( SELECT RecTime AS t, message AS m FROM `demay_farm`.`mqttmessages` WHERE topic = 'e8db84e569cf/data' AND RecTime > '2021-10-24 14:24:00' )
DO CALL add_pt_to_gate_open(rec.t, json_value(rec.m, '$.GateOpen'));
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
    {"MachineID":"e8db84e302d0","SampleTime":"2021-09-21 20:36:09-0700","MotionDetected":"ON","Temperature":84.38,"Humidity":13.9,"ConsolePower":"ON","PublishReason":"M---"}
    */
    IF NEW.topic = 'e8db84e302d0/data' THEN
        CALL  add_pt_to_kitchenMTH_motion(NEW.rectime, json_value(NEW.message, '$.MotionDetected') = 'ON');
        INSERT IGNORE INTO `demay_farm`.`kitchenMTH_temp` SET time = NEW.rectime, value = json_value(NEW.message, '$.Temperature');
        INSERT IGNORE INTO `demay_farm`.`kitchenMTH_hum` SET time = NEW.rectime, value = json_value(NEW.message, '$.Humidity');
        LEAVE `whole_proc`;
    END IF;
    /* Gate data.
    {"MachineID":"e8db84e569cf","SampleTime":"2021-11-20 08:24:24-0800","GateOpen":false,"GateAngle":1.098096,"BatteryVolts":12.9639,"PublishReason":"----","RawX":462,"RawY":-296,"RawZ":-335,"GateOperate":false}
      */
    IF NEW.topic = 'e8db84e569cf/data' THEN
        CALL  add_pt_to_gate_open(NEW.rectime, json_value(NEW.message, '$.GateOpen'));
        INSERT IGNORE INTO `demay_farm`.`gate_angle` SET time = NEW.RecTime, value = json_value(NEW.message, '$.GateAngle');
        INSERT IGNORE INTO `demay_farm`.`gate_battery` SET time = NEW.RecTime, value = json_value(NEW.message, '$.BatteryVolts');
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
 IF NEW.entity_id='sensor.dining_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_bed_enviro_air_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_air_temperature_3' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bedroom_temperature' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`master_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_enviro_air_temperature_2' AND NEW.state < 140 AND NEW.state > 20 THEN
  INSERT IGNORE INTO `demay_farm`.`living_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.state NOT LIKE 'unknown' AND NEW.entity_id='climate.thermostat' THEN
  INSERT IGNORE INTO `demay_farm`.`thermostat_temp` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(json_value(NEW.attributes,'$.current_temperature'));
  INSERT IGNORE INTO `demay_farm`.`thermostat_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(json_value(NEW.attributes,'$.current_humidity'));
  INSERT IGNORE INTO `demay_farm`.`ac_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=if(json_value(NEW.attributes,'$.hvac_action')='idle',0.0, if(json_value(NEW.attributes,'$.equipment_running')='compCool1,fan',2100.0, 100.0));
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.dining_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_bed_enviro_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_enviro_humidity_3' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bedroom_humidity' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`master_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_enviro_humidity_2' AND NEW.state < 110 AND NEW.state > -10 THEN
  INSERT IGNORE INTO `demay_farm`.`living_hum` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.computer_room_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`computer_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.dining_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.guest_heater_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_heater_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bed_heater_switch_electric_consumed_w' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`master_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_heater_electric_consumed_w_4' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`living_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.humidifier_switch_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`humidifier_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.sensor.refrigerator_electric_consumed_w' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`fridge_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='switch.livingroom' THEN
  INSERT IGNORE INTO `demay_farm`.`lrlight_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=if(NEW.state='on', 100.0, 0.0);
  LEAVE `whole_proc`;
 END IF;


 IF NEW.entity_id='binary_sensor.living_motion' THEN
  CALL `demay_farm`.`add_pt_to_living_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.dining_motion' THEN
  CALL `demay_farm`.`add_pt_to_dining_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.kitchen_motion' THEN
  CALL `demay_farm`.`add_pt_to_kitchen_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;
IF NEW.entity_id='binary_sensor.guest_motion' THEN
  CALL `demay_farm`.`add_pt_to_guest_motion`(TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), NEW.state='on');
  LEAVE `whole_proc`;
 END IF;

END;
$$
DELIMITER ;
