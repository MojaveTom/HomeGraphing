#!/usr/bin/env python3

'''
# This is how to get weather information from ambientweather.net:
#  It should be in its own program that inserts the data to the database at regular
#  intervals.  We can get about 24 hours at a time (288) data points; but we can
#  specify the ending date/time we are interested in retrieving.
# Probably should run a cron job every 12 hours to get the previous 24 hours of data
#  and let the database sort out the duplicates.

'''

import pymysql as mysql
from pymysql.err import Error as DbError
import time
import datetime
from datetime import date
from datetime import timedelta
from datetime import datetime as dt
import os
import argparse
import sys
import time
import configparser
import logging
import logging.config
import logging.handlers
import json

ProgName, ext = os.path.splitext(os.path.basename(sys.argv[0]))
ProgPath = os.path.dirname(os.path.realpath(sys.argv[0]))
logConfFileName = os.path.join(ProgPath, ProgName + '_loggingconf.json')
if os.path.isfile(logConfFileName):
    try:
        with open(logConfFileName, 'r') as logging_configuration_file:
            config_dict = json.load(logging_configuration_file)
        if 'log_file_path' in config_dict:
            logPath = os.path.expandvars(config_dict['log_file_path'])
            os.makedirs(logPath, exist_ok=True)
        else:
            logPath=""
        for p in config_dict['handlers'].keys():
            if 'filename' in config_dict['handlers'][p]:
                config_dict['handlers'][p]['filename'] = os.path.join(logPath, config_dict['handlers'][p]['filename'])
        logging.config.dictConfig(config_dict)
    except Exception as e:
        print("loading logger config from file failed.")
        print(e)
        pass

logger = logging.getLogger(__name__)
logger.info('logger name is: "%s"', logger.name)
logging.getLogger('matplotlib.axes._base').setLevel('WARNING')      # turn off matplotlib info & debug messages
logging.getLogger('matplotlib.font_manager').setLevel('WARNING')

def GetConfigFilePath():
    fp = os.path.join(ProgPath, 'secrets.ini')
    if not os.path.isfile(fp):
        fp = os.environ['PrivateConfig']
        if not os.path.isfile(fp):
            logger.error('No configuration file found.')
            sys.exit(1)
    logger.info('Using configuration file at: %s', fp)
    return fp

from ambient_api import ambientapi

#######################   GLOBALS   ########################
ServerTimeFromUTC = timedelta(hours=0)
RequiredConfigParams = frozenset(('ambient_endpoint', 'ambient_api_key', 'ambient_application_key', 'inserter_host', 'inserter_schema', 'inserter_port', 'inserter_user', 'inserter_password', 'weather_table'))

DBConn = None
dontWriteDb = True

#  Generate a timezone for  LocalStandardTime
#  Leaving off zone name from timezone creator generates UTC based name which may be more meaningful.
localStandardTimeZone = datetime.timezone(-datetime.timedelta(seconds=time.timezone))
logger.debug('LocalStandardTime ZONE is: %s'%localStandardTimeZone)


#######################   FUNCTIONS   ########################

def FillDatabaseHoles(Table):


    pass

def main():
    global DBConn, dontWriteDb, localStandardTimeZone
    logger.debug("Entered main.")
    parser = argparse.ArgumentParser(
        description='Retrieve weather data from Ambient.net.')
    parser.add_argument("-o", "--oldData", dest="desiredFirst", action="store", help="Set desired first database date.")
    parser.add_argument("-W", "--dontWriteToDB", dest="noWriteDb", action="store_true", default=False, help="Don't write to database [during debug defaults to True].")
    parser.add_argument("-v", "--verbosity", dest="verbosity",
                        action="count", help="Increase output verbosity", default=0)
    args = parser.parse_args()
    Verbosity = args.verbosity
    firstDate = None
    if args.desiredFirst is not None:
        try:
            firstDate = dt.fromisoformat(args.desiredFirst)
            logger.info("Desired first date is: %s", str(firstDate))
        except Exception as e:
            logger.error("Old data retrieval aborted because given time was ill-formatted.")
            logger.info("--oldData time was specified as: %s", args.desiredFirst)
            logger.exception(e)
    else:
        logger.info("No historical weather data desired.")

    config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
    configFile = GetConfigFilePath()

    config.read(configFile)
    cfgSection = os.path.basename(sys.argv[0])+"/"+os.environ['HOST']
    logger.info("INI file cofig section is: %s", cfgSection)
    if not config.has_section(cfgSection):
        logger.critical('Config file "%s", has no section "%s".', configFile, cfgSection)
        sys.exit(2)
    if set(config.options(cfgSection)) < RequiredConfigParams:
        logger.critical('Config  section "%s" does not have all required params: "%s", it has params: "%s".', cfgSection, RequiredConfigParams, set(config.options(cfgSection)))
        sys.exit(3)

    cfg = config[cfgSection]

    user = cfg['inserter_user']
    pwd  = cfg['inserter_password']
    host = cfg['inserter_host']
    port = int(cfg['inserter_port'])
    myschema = cfg['inserter_schema']
    endpoint = cfg['ambient_endpoint']
    api_key = cfg['ambient_api_key']
    app_key = cfg['ambient_application_key']
    weather_table = cfg['weather_table']
    myWeatherDevice = cfg['MAC_address']

    DBConn = mysql.connect(host=host, port=port, user=user, password=pwd, database=myschema, binary_prefix=True, charset='utf8mb4')
    logger.debug('DBConn is: %s'%DBConn)

    with DBConn.cursor() as Iconn:
        logger.info("Insertion connection to database established.")
        Ambient_api = ambientapi.AmbientAPI(AMBIENT_ENDPOINT=endpoint \
            , AMBIENT_API_KEY=api_key \
            # log_levels are: debug, info, warning, error, critical, console (just prints message)
            # log_file is ignored if log_level is 'console'
            , AMBIENT_APPLICATION_KEY=app_key \
            , log_level='console' if Verbosity >= 1 else None \
            , log_file='ambient.log' if Verbosity >= 1 else None \
            )

        devices = Ambient_api.get_devices()
        logger.debug("Weather stationS info: %s", devices)
        device = None
        for d in devices:
            logger.debug("Weather station info: %s", d.info)
            logger.debug("MAC address of weather station: %s", d.mac_address)
            if d.mac_address == myWeatherDevice.upper():
                device = d
                logger.debug('Found desired weather station: %s' % myWeatherDevice)
                break
            pass

        if device is None:
            logger.critical('Desired weather station data not found at AmbientWeather. %s' % myWeatherDevice)
            exit(1)

        Iconn.execute("SELECT date FROM `"+myschema+"`.`"+weather_table+"` ORDER BY date DESC LIMIT 2")
        lastTimeInDb = None
        nextToLastTime = None
        for r in Iconn:
            if lastTimeInDb is None: lastTimeInDb = r[0]
            elif nextToLastTime is None:
                nextToLastTime = r[0]
                break
        logger.debug('lastTimeInDb: %s, nextToLastTime: %s', lastTimeInDb, nextToLastTime)
        Iconn.execute("SELECT date FROM `"+myschema+"`.`"+weather_table+"` ORDER BY date LIMIT 1")
        firstTimeInDb = None
        for r in Iconn:
            firstTimeInDb = r[0]
        logger.debug('firstTimeInDb: %s', firstTimeInDb)
        if lastTimeInDb and nextToLastTime:
            timeDiff = lastTimeInDb - nextToLastTime
        else:
            timeDiff = timedelta(minutes=5)
        if timeDiff > timedelta(minutes=5):
            timeDiff = timedelta(minutes=5)
        nowTime = dt.now()
        if lastTimeInDb:
            numNew = int((nowTime - lastTimeInDb) / timeDiff)
        else:
            numNew = 288
        logger.info("lastTimeInDb: %s; nextToLastTime: %s; timeDiff: %s", lastTimeInDb, nextToLastTime, timeDiff)
        logger.info("nowTime: %s", nowTime)
        logger.info("Number of new data points is: %s", numNew)

        tzsavesql = "SET @oldtz=@@session.time_zone"
        tzsetUTC  = "SET @@session.time_zone='+00:00'"
        tzrestoresql = "SET @@session.time_zone=@oldtz"
        logger.debug('tzsavesql: %s', tzsavesql)
        logger.debug('tzsetUTC: %s', tzsetUTC)
        logger.debug('tzrestoresql: %s', tzrestoresql)
        try:
            Iconn.execute(tzsavesql)
            Iconn.execute(tzsetUTC)
        except DbError as e:
            _ = e
            logger.error("Caught DbError exception settinmg time_zone: %s", e)
            logger.exception(e)
            DBConn.rollback()
            pass

        time.sleep(2)       # Wait a while for Ambient server to recover: at least 1 sec.

        logger.debug('Get %s data points from Ambient Weather.'%str(numNew+2))
        wdata = device.get_data(limit=numNew+2)     # Get a couple duplicates "just in case"
        if len(wdata) > 0:
            logger.debug("Length, type of weather device data: %s, %s, %s", len(wdata), type(wdata), type(wdata[0]))
            logger.info("Weather device data: %s", wdata)
            for dp in wdata:
                insertsql = "INSERT IGNORE INTO `"+myschema+"`.`"+weather_table+"` "+str(tuple(dp.keys())).replace("'", "") \
                    +" VALUES "+str(tuple(dp.values())).replace("Z","")+" ON DUPLICATE KEY UPDATE date = VALUES(date)"
                logger.debug("Insert SQL: %s", insertsql)
                try:
                    Iconn.execute(insertsql)
                except DbError as e:
                    _ = e
                    logger.warning("Caught DbError exception inserting data: %s", e)
                    logger.exception(e)
                    DBConn.rollback()
                    break
        else:
            logger.info("No new weather data retrieved.")

        if (firstDate is not None) and (firstTimeInDb is not None) and (firstDate >= firstTimeInDb):
            logger.info("Database already has desired historical data.")
        elif (firstDate is not None) and (firstTimeInDb is not None) and (firstDate < firstTimeInDb):
            logger.info("Trying to retrieve historical weather data before: %s back to: %s", firstTimeInDb, firstDate)
            time.sleep(2)       # wait for ambient serv er to recover
            wdata = device.get_data(end_date = firstTimeInDb)
            if len(wdata) > 0:
                logger.debug("Length, type of weather device data: %s, %s, %s", len(wdata), type(wdata), type(wdata[0]))
                logger.info("Weather device data: %s", wdata)
                for dp in wdata:
                    insertsql = "INSERT IGNORE INTO `"+myschema+"`.`"+weather_table+"` " \
                            + str(tuple(dp.keys())).replace("'", "") \
                            + " VALUES " \
                            + str(tuple(dp.values())).replace("Z","") \
                            + " ON DUPLICATE KEY UPDATE date = VALUES(date)"
                    logger.debug("Insert SQL: %s", insertsql)
                    try:
                        Iconn.execute(insertsql)
                    except DbError as e:
                        _ = e
                        logger.warning("Caught DbError exception inserting data: %s", e)
                        logger.exception(e)
                        DBConn.rollback()
                        break
            else:
                logger.info("No historical data retrieved.")

        try:
            Iconn.execute(tzrestoresql)
            # DBConn.commit()
        except DbError as e:
            _ = e
            logger.warning("Caught DbError exception restoring timezone: %s", e)
            logger.exception(e)
            DBConn.rollback()
            pass
        DBConn.commit()

if __name__ == "__main__":
    main()
    pass
