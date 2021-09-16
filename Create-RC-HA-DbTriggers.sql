

CREATE TABLE IF NOT EXISTS  `demay_farm`.`dining_hum` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`guest_hum` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`kitchen_hum` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`master_hum` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`living_hum` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`thermostat_hum` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`humidifier_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`fridge_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`lrlight_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`ac_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`computer_heater_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`dining_heater_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`guest_heater_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`kitchen_heater_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`master_heater_power` LIKE  `demay_farm`.`dining_temp`;
CREATE TABLE IF NOT EXISTS  `demay_farm`.`living_heater_power` LIKE  `demay_farm`.`dining_temp`;

CREATE OR REPLACE TABLE  `demay_farm`.`md` (
    `RecordId`       INTEGER NOT NULL
  , `Time`           TIMESTAMP(6) NOT NULL PRIMARY KEY DEFAULT current_timestamp(6)
  , `MeterTime`      DATETIME
  , `CuFtWater`      DOUBLE
  , `GPM`            DOUBLE
  , `HouseEnergyKWH` DOUBLE
  , `HousePowerW`    DOUBLE
  , `AvgPowerW`      DOUBLE
  , `WaterSysKwh`    DOUBLE
  , `AvgWaterPowerW` DOUBLE
  , `WaterEnable`    DOUBLE
);

RENAME TABLE meterdata TO temp_table,
  md TO meterdata,
  temp_table to md;

DELIMITER //
CREATE OR REPLACE TRIGGER munchMeterData
AFTER INSERT ON `demay_farm`.`000300002570_A_RawMeterData`
FOR EACH ROW
`whole_proc`:
BEGIN
  INSERT IGNORE INTO `demay_farm`.`meterdata`
    SELECT NEW.`idRawMeterData`
    , NEW.`ComputerTime`                                                                      /* AS `Time` */
    , NEW.`MeterTime`                                                                         /* AS `MeterTime` */
    , round(SUBSTR(NEW.`MeterData`,220,8) * 0.1,1)                                            /* AS `CuFtWater` */
    , round((SUBSTR(NEW.`MeterData`,220,8) - SUBSTR(`rmd1`.`MeterData`,220,8))
      / (UNIX_TIMESTAMP(NEW.`ComputerTime`) + MICROSECOND(NEW.`ComputerTime`)
      / 1000000.0 - (UNIX_TIMESTAMP(`rmd1`.`ComputerTime`) + MICROSECOND(`rmd1`.`ComputerTime`)
      / 1000000.0)) * 0.74805194703778 * 60,3)                                                /* AS `GPM` */
    , round(SUBSTR(NEW.`MeterData`,17,8) / pow(10,SUBSTR(NEW.`MeterData`,231,1)),2)           /* AS `HouseEnergyKWH` */
    , SUBSTR(NEW.`MeterData`,153,7) + 0.0                                                     /* AS `HousePowerW` */
    , round((SUBSTR(NEW.`MeterData`,17,8) - SUBSTR(`rmd1`.`MeterData`,17,8)) * 1000.0
      / pow(10,SUBSTR(NEW.`MeterData`,231,1))
      / ((UNIX_TIMESTAMP(NEW.`ComputerTime`) + MICROSECOND(NEW.`ComputerTime`)
      / 1000000.0 - (UNIX_TIMESTAMP(`rmd1`.`ComputerTime`) + MICROSECOND(`rmd1`.`ComputerTime`)
      / 1000000.0)) / 3600.0),0)                                                              /* AS `AvgPowerW` */
    , round((SUBSTR(NEW.`MeterData`,204,8) + SUBSTR(NEW.`MeterData`,212,8)) * 0.001,3)        /* AS `WaterSysKwh` */
    , round((SUBSTR(NEW.`MeterData`,204,8) + SUBSTR(NEW.`MeterData`,212,8) - (SUBSTR(`rmd1`.`MeterData`,204,8) + SUBSTR(`rmd1`.`MeterData`,212,8)))
      / ((UNIX_TIMESTAMP(NEW.`ComputerTime`) + MICROSECOND(NEW.`ComputerTime`)
      / 1000000.0 - (UNIX_TIMESTAMP(`rmd1`.`ComputerTime`) + MICROSECOND(`rmd1`.`ComputerTime`) / 1000000.0))
      / 3600.0),0)                                                                           /* AS `AvgWaterPowerW` */
    , SUBSTR(NEW.`MeterData`,230,1) % 2                                                      /* AS `WaterEnable`  */
    FROM (`000300002570_a_rawmeterdata` JOIN `000300002570_a_rawmeterdata` `rmd1` ON (`rmd1`.`idRawMeterData` = NEW.`idRawMeterData` - 1));
END; //

DELIMITER ;

INSERT IGNORE INTO `demay_farm`.`md`
  SELECT `rmd`.`idRawMeterData`                                                             /* AS `RecordId`  */
    , `rmd`.`ComputerTime`                                                                  /* AS `Time`  */
    , `rmd`.`MeterTime`                                                                     /* AS `MeterTime`  */
    , round(substr(`rmd`.`MeterData`,220,8) * 0.1,1)                                        /* AS `CuFtWater`  */
    , round((substr(`rmd`.`MeterData`,220,8) - substr(`rmd1`.`MeterData`,220,8))
        / (unix_timestamp(`rmd`.`ComputerTime`) + microsecond(`rmd`.`ComputerTime`)
        / 1000000.0 - (unix_timestamp(`rmd1`.`ComputerTime`) + microsecond(`rmd1`.`ComputerTime`)
        / 1000000.0)) * 0.74805194703778 * 60,3)                                            /* AS `GPM`  */
    , round(substr(`rmd`.`MeterData`,17,8) / pow(10,substr(`rmd`.`MeterData`,231,1)),2)     /* AS `HouseEnergyKWH`  */
    , substr(`rmd`.`MeterData`,153,7) + 0.0                                                 /* AS `HousePowerW`  */
    , round((substr(`rmd`.`MeterData`,17,8) - substr(`rmd1`.`MeterData`,17,8)) * 1000.0
        / pow(10,substr(`rmd`.`MeterData`,231,1))
        / ((unix_timestamp(`rmd`.`ComputerTime`) + microsecond(`rmd`.`ComputerTime`)
        / 1000000.0 - (unix_timestamp(`rmd1`.`ComputerTime`) + microsecond(`rmd1`.`ComputerTime`)
        / 1000000.0)) / 3600.0),0)                                                          /* AS `AvgPowerW`  */
    , round((substr(`rmd`.`MeterData`,204,8) + substr(`rmd`.`MeterData`,212,8)) * 0.001,3)  /* AS `WaterSysKwh`  */
    , round((substr(`rmd`.`MeterData`,204,8) + substr(`rmd`.`MeterData`,212,8) - (substr(`rmd1`.`MeterData`,204,8) + substr(`rmd1`.`MeterData`,212,8)))
        / ((unix_timestamp(`rmd`.`ComputerTime`) + microsecond(`rmd`.`ComputerTime`)
        / 1000000.0 - (unix_timestamp(`rmd1`.`ComputerTime`) + microsecond(`rmd1`.`ComputerTime`) / 1000000.0))
        / 3600.0),0)                                                                        /* AS `AvgWaterPowerW`  */
    , substr(`rmd`.`MeterData`,230,1) % 2                                                   /* AS `WaterEnable`   */
  FROM (`000300002570_a_rawmeterdata` `rmd` JOIN `000300002570_a_rawmeterdata` `rmd1` ON(`rmd1`.`idRawMeterData` = `rmd`.`idRawMeterData` - 1));

/* Trigger on hameassistang states table to save interesting values to individual tables.  Includes motion.
 */
DELIMITER //
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

 IF NEW.entity_id='sensor.computer_room_heater_electric_consumed_w_7' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`computer_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.dining_heater_electric_consumed_w_5' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`dining_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.smart_switch_6_electric_consumed_w' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`guest_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.kitchen_heater_electric_consumed_w_6' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.master_bed_heater_power' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`master_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;
 IF NEW.entity_id='sensor.living_room_heater_electric_consumed_w_4' AND NEW.state < 5000 THEN
  INSERT IGNORE INTO `demay_farm`.`living_heater_power` SET time=TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), NEW.created), value=round(NEW.state, 1);
  LEAVE `whole_proc`;
 END IF;

 IF NEW.entity_id='sensor.humidifier_electric_consumed_w_3' AND NEW.state < 5000 THEN
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

/* Motion sensors */
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

END; //

DELIMITER ;

/* For new_ha database */
/* find motion sensors */
select distinct(entity_id) from `new_ha`.`states` where entity_id like 'binary_sensor.%motion%';
select * from `new_ha`.`states` where entity_id like 'binary_sensor.multisensor_6_home_security_motion_detection%' order by state_id desc limit 3;

/* Motion tables creation, initial loading and triggers in HomeGraphing directory.
 */


/* SQL to load sensor tables from state table.
 */
INSERT IGNORE INTO `demay_farm`.`dining_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.dining_enviro_air_temperature'
    AND `new_ha`.`states`.`state` < 140 AND `new_ha`.`states`.`state` > 20
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`guest_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.guest_bed_enviro_air_temperature'
    AND `new_ha`.`states`.`state` < 140 AND `new_ha`.`states`.`state` > 20
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`kitchen_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.kitchen_enviro_air_temperature_3'
    AND `new_ha`.`states`.`state` < 140 AND `new_ha`.`states`.`state` > 20
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`master_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.master_bedroom_temperature'
    AND `new_ha`.`states`.`state` < 140 AND `new_ha`.`states`.`state` > 20
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`living_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.living_room_enviro_air_temperature_2'
    AND `new_ha`.`states`.`state` < 140 AND `new_ha`.`states`.`state` > 20
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`thermostat_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(json_value(`new_ha`.`states`.`attributes`,'$.current_temperature'))
  FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='climate.thermostat'
    AND `new_ha`.`states`.`created` > '2021-07-25';
INSERT IGNORE INTO `demay_farm`.`thermostat_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(json_value(`new_ha`.`states`.`attributes`,'$.current_humidity'))
  FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='climate.thermostat'
    AND `new_ha`.`states`.`created` > '2019-08-18 10:32:33';
INSERT IGNORE INTO `demay_farm`.`ac_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), if(json_value(NEW.attributes,'$.hvac_action')='idle',0.0, if(json_value(NEW.attributes,'$.equipment_running')='compCool1,fan',2100.0, 100.0))
  FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='climate.thermostat'
    AND `new_ha`.`states`.`created` > '2019-08-18 10:32:33';

INSERT IGNORE INTO `demay_farm`.`dining_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.dining_enviro_humidity'
    AND `new_ha`.`states`.`state` < 110 AND `new_ha`.`states`.`state` > -10
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`guest_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.guest_bed_enviro_humidity'
    AND `new_ha`.`states`.`state` < 110 AND `new_ha`.`states`.`state` > -10
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`kitchen_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.kitchen_enviro_humidity_3'
    AND `new_ha`.`states`.`state` < 110 AND `new_ha`.`states`.`state` > -10
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`master_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.master_bedroom_humidity'
    AND `new_ha`.`states`.`state` < 110 AND `new_ha`.`states`.`state` > -10
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`living_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.living_room_enviro_humidity_2'
    AND `new_ha`.`states`.`state` < 110 AND `new_ha`.`states`.`state` > -10
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`computer_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.computer_room_heater_electric_consumed_w_7'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`dining_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.dining_heater_electric_consumed_w_5'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`guest_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.smart_switch_6_electric_consumed_w'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.kitchen_heater_electric_consumed_w_6'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`master_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.master_bed_heater_power'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`living_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.living_room_heater_electric_consumed_w_4'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`humidifier_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.humidifier_electric_consumed_w_3'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`fridge_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), round(`new_ha`.`states`.`state`, 1) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='sensor.refrigerator_electric_consumed_w'
    AND `new_ha`.`states`.`state` < 5000
    AND `new_ha`.`states`.`created` > '2021-07-25';

INSERT IGNORE INTO `demay_farm`.`lrlight_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `new_ha`.`states`.`created`), if(state='on', 100.0, 0.0) FROM `new_ha`.`states`
  WHERE `new_ha`.`states`.`state` NOT LIKE 'unknown'
    AND `new_ha`.`states`.`entity_id`='switch.livingroom'
    AND `new_ha`.`states`.`created` > '2021-07-25';


/* For homeassistant database.

INSERT IGNORE INTO `demay_farm`.`dining_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.dining_enviro_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > 20
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`guest_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.guest_bed_enviro_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > 20
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`kitchen_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_enviro_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > 20
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`master_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_bedroom_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > 20
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`living_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_room_enviro_temperature'
    AND `homeassistant`.`states`.`state` < 140 AND `homeassistant`.`states`.`state` > 20
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`thermostat_temp` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(json_value(`homeassistant`.`states`.`attributes`,'$.current_temperature'))
  FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='climate.thermostat'
    AND `homeassistant`.`states`.`created` > '2018-12-01';
INSERT IGNORE INTO `demay_farm`.`thermostat_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(json_value(`homeassistant`.`states`.`attributes`,'$.current_humidity'))
  FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='climate.thermostat'
    AND `homeassistant`.`states`.`created` > '2019-08-18 10:32:33';
INSERT IGNORE INTO `demay_farm`.`ac_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), if(json_value(attributes,'$.hvac_action')='idle',0.0, if(json_value(attributes,'$.operation')='cool',2100.0, 100.0))
  FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='climate.thermostat'
    AND `homeassistant`.`states`.`created` > '2019-08-18 10:32:33';

INSERT IGNORE INTO `demay_farm`.`dining_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.dining_enviro_relative_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`guest_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.guest_bed_enviro_relative_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`kitchen_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_enviro_relative_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`master_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_bedroom_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`living_hum` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_room_enviro_relative_humidity'
    AND `homeassistant`.`states`.`state` < 110 AND `homeassistant`.`states`.`state` > -10
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`computer_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.computer_room_heater_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`dining_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.dining_room_heater_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`guest_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.guest_bed_heater_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`kitchen_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.kitchen_heater_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`master_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.master_bed_heater_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`living_heater_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.living_room_heater_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`humidifier_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.humidifier_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`fridge_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), round(`homeassistant`.`states`.`state`, 1) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='sensor.refrigerator_power'
    AND `homeassistant`.`states`.`state` < 5000
    AND `homeassistant`.`states`.`created` > '2018-12-01';

INSERT IGNORE INTO `demay_farm`.`lrlight_power` (time, value)
  SELECT TIMESTAMPADD(SECOND, TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW()), `homeassistant`.`states`.`created`), if(state='on', 100.0, 0.0) FROM `homeassistant`.`states`
  WHERE `homeassistant`.`states`.`state` NOT LIKE 'unknown'
    AND `homeassistant`.`states`.`entity_id`='switch.livingroom_switch'
    AND `homeassistant`.`states`.`created` > '2018-12-01';
*/
