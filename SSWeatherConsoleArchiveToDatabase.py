#!/usr/bin/env python3

import pandas as pd
import numpy as np

import time
import datetime
from datetime import date
from datetime import timedelta
from datetime import datetime
import os
import argparse
import sys
import math
from sqlalchemy import create_engine
import pymysql as mysql
import pymysql.err as Error
import configparser
import logging
import logging.config
import logging.handlers
import json

ProgName, ext = os.path.splitext(os.path.basename(sys.argv[0]))
ProgPath = os.path.dirname(os.path.realpath(sys.argv[0]))
logConfFileName = os.path.join(ProgPath, ProgName + '_loggingconf.json')
# print('logConfFileName is "%s"'%logConfFileName)
if os.path.isfile(logConfFileName):
    try:
        with open(logConfFileName, 'r') as logging_configuration_file:
            # print('logConfFileName opened')
            config_dict = json.load(logging_configuration_file)
            # print('config dict loaded')
        if 'log_file_path' in config_dict:
            logPath = os.path.expandvars(config_dict['log_file_path'])
            os.makedirs(logPath, exist_ok=True)
        else:
            logPath=""
        for p in config_dict['handlers'].keys():
            if 'filename' in config_dict['handlers'][p]:
                logFileName = os.path.join(logPath, config_dict['handlers'][p]['filename'])
                config_dict['handlers'][p]['filename'] = logFileName
        logging.config.dictConfig(config_dict)
    except Exception as e:
        print("loading logger config from file failed.")
        print(e)
        pass
else:
    print('logConfFile "%s" does not exist.'%logConfFileName)


logger = logging.getLogger(__name__)
logger.info('logger name is: "%s"', logger.name)
logger.setLevel('DEBUG')

DBConn = None
DBCursor = None
Topics = []    # default topics to subscribe
mqtt_msg_table = None
RequiredConfigParams = frozenset((
    'inserter_host'
  , 'inserter_schema'
  , 'inserter_port'
  , 'inserter_user'
  , 'inserter_password'
  , 'weather_table'
))

def GetConfigFilePath():
    fp = os.path.join(ProgPath, 'secrets.ini')
    if not os.path.isfile(fp):
        fp = os.environ['PrivateConfig']
        if not os.path.isfile(fp):
            logger.error('No configuration file found: %s', fp)
            sys.exit(1)
    logger.info('Using configuration file at: %s', fp)
    return fp

def main():
    config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
    configFile = GetConfigFilePath()
    configFileDir = os.path.dirname(configFile)

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

    parser = argparse.ArgumentParser(description = 'Program to read Ambient WS-1002 console archived data and insert it into the database.')
    parser.add_argument("files", action="append", nargs="*", help="List of CSV files to process.")
    parser.add_argument("-b", "--beginTime", dest="begin", action="append", help="Beginning time(s) to insert data to database.")
    parser.add_argument("-e", "--endTime", dest="end", action="append", help="Ending time(s) to insert data to database.")
    parser.add_argument("-g", "--maxGap", dest="maxGap", action="store", help="(minutes) Max gap in database data to ignore; gaps bigger that this will be filled in.", default='20')
    parser.add_argument("-d", "--dryrun", dest="dryrun", action="store_true", help="Don't actually modify database.", default=False)
    parser.add_argument("-v", "--verbosity", dest="verbosity", action="count", help="increase output verbosity", default=0)
    args = parser.parse_args()
    # numDays = float(args.days)

    logger.debug('The arguments are: %s'%args)
    argfileslist = args.files[0]
    logger.debug('There are %s input files on the command line.'% len(argfileslist))
    logger.debug('The input file list is: %s'%(argfileslist))
    if len(argfileslist) == 0:
        logger.critical('A list of CSV files is required.')
        exit(3)

    beginTimes = list()
    endTimes = list()
    if args.begin is not None and args.end is not None :
        try:
            logger.debug('Intreperting begin times: %s'%args.begin)
            for b in args.begin:
                logger.debug('Looking at %s'%b)
                beginTimes.append(datetime.fromisoformat(b))
        except Exception as e:
            logger.critical('Unable to parse begin time: "%s"'%args.begin)
            logger.exception(e)
            exit(3)
        try:
            logger.debug('Intreperting end times: %s'%args.end)
            for b in args.end:
                logger.debug('Looking at %s'%b)
                endTimes.append(datetime.fromisoformat(b))
        except Exception as e:
            logger.critical('Unable to parse begin time: "%s"'%args.end)
            logger.exception(e)
            exit(3)
        logger.debug('Begin times: %s, End times: %s'%(beginTimes, endTimes))
        if len(beginTimes) != len(endTimes):
            logger.critical('There must be same number of begin times and end times.')
            exit(3)
    else:
        logger.debug('begin or end time is "None"')

    user = cfg['inserter_user']
    pwd  = cfg['inserter_password']
    host = cfg['inserter_host']
    port = cfg['inserter_port']
    schema = cfg['inserter_schema']
    tableName = cfg['weather_table']
    logger.info("user %s"%(user,))
    logger.info("pwd %s"%(pwd,))
    logger.info("host %s"%(host,))
    logger.info("port %s"%(port,))
    logger.info("schema %s"%(schema,))
    logger.info("Table %s"%(tableName,))

    '''
SQL commands to view gaps:

create temporary table w1 like weather;
alter table w1 drop primary key;
alter table w1 add column id int auto_increment primary key first;
insert into w1 (dateutc, tempinf, tempf, humidityin, humidity, windspeedmph, windgustmph, maxdailygust, winddir, baromabsin, baromrelin, hourlyrainin, dailyrainin, weeklyrainin, monthlyrainin, yearlyrainin, solarradiation, uv, feelsLike, dewPoint, lastRain, date) select * from weather order by date;
select  wB.date as beginTime,  wA.date as endTime, round((wA.dateutc - wB.dateutc)/60000) as diff from w1 as wA inner join w1 as wB on wA.id=wB.id+1 where (wA.dateutc - wB.dateutc)/60000 > 20;
drop table w1;
    '''
    connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=schema)
    Eng = create_engine(connstr, echo = True if args.verbosity>=2 else False, logging_name = logger.name)
    logger.debug(Eng)
    with Eng.connect() as conn, conn.begin():
        if args.begin is None or args.end is None:
            logger.debug('Auto detecting gaps in weather table.')
            logger.debug('Create temporary table.')
            conn.execute('create temporary table w1 like weather')
            logger.debug('Drop primary key on temporary table.')
            conn.execute('alter table w1 drop primary key')
            logger.debug('Add id column to temporary table.')
            conn.execute('alter table w1 add column id int auto_increment primary key first')
            logger.debug('Copy rows from weather to temporary table.')
            conn.execute('insert into w1 (dateutc, tempinf, tempf, humidityin, humidity, windspeedmph, windgustmph, maxdailygust, winddir, baromabsin, baromrelin, hourlyrainin, dailyrainin, weeklyrainin, monthlyrainin, yearlyrainin, solarradiation, uv, feelsLike, dewPoint, lastRain, date) select * from weather order by date')
            gapQuery = 'select  wB.date as beginTime,  wA.date as endTime, round((wA.dateutc - wB.dateutc)/60000) as diff from w1 as wA inner join w1 as wB on wA.id=wB.id+1 where (wA.dateutc - wB.dateutc)/60000 > %s'%args.maxGap
            logger.debug('Select time gaps with query: "%s"'%gapQuery)
            result = conn.execute(gapQuery)
            for row in result:
                b = row[0]
                e = row[1]
                beginTimes.append(b)
                endTimes.append(e)
                logger.debug('Appending %s to beginTimes, %s to endTimes, because the gap was %s'%(b, e, row[2]))
            logger.debug('Auto detected gaps are: begin %s, end %s'%(beginTimes, endTimes))
            logger.debug('Drop temporary table.')
            conn.execute('drop table w1')
            pass
        insertQuery = 'INSERT IGNORE INTO ' + tableName + '(dateutc, date, tempinf, humidityin, tempf, humidity, windspeedmph, windgustmph,\
            dewPoint, feelsLike, winddir, baromabsin, baromrelin, hourlyrainin, dailyrainin, weeklyrainin, monthlyrainin, \
            yearlyrainin, solarradiation, uv) VALUES \n'
        linebegin = '  ('
        valuesCount = 0
        logger.debug('zipped times: %s'%list(zip(beginTimes, endTimes)))
        for beginTime, endTime in list(zip(beginTimes, endTimes)):
            logger.debug('Scanning files for entries between "%s" and "%s"'%(beginTime, endTime))
            for theFile in argfileslist:
                logger.info('theFile: %s', theFile)
                lineCount = 0
                with open(theFile, encoding='utf_16_le') as f:
                    l = f.readline()            # discard first line
                    printFirstTime = True
                    for l in f:
                        fields = l.replace('--.-', 'null').replace('--', 'null').replace('\n','').split('\t')
                        dt = datetime.strptime(fields[1], '%I:%M %p %m/%d/%Y')
                        if printFirstTime:
                            logger.debug('First time in file is %s'%dt.isoformat())
                            printFirstTime = False
                        if dt <= beginTime:
                            continue
                        if dt >= endTime:
                            break
                        lineCount += 1
                        fields[1] = dt.isoformat()
                        ol = linebegin + str([str(round(dt.timestamp()*1000)), fields[1:9],fields[9] if fields[9] != 'null' else fields[19], fields[10:19], fields[21]]).replace('[','').replace(']','').replace("'null'", "NULL") + ')\n'
                        linebegin = ', ('
                        insertQuery += ol
                    logger.debug('Last time in file is %s'%dt.isoformat())
                    logger.debug('There were %s lines in the file within the desired times.'%lineCount)
                    valuesCount += lineCount
        logger.debug('Insert the values.')
        insertQuery += ' ON DUPLICATE KEY UPDATE date=value(date)'
        logger.debug('All together, there were %s values to add to the database.'%valuesCount)
        logger.debug('The insert query is: "%s"'%insertQuery)
        if (not args.dryrun) and (valuesCount > 0):
            conn.execute(insertQuery)
        else:
            if valuesCount == 0:
                logger.warning('No data found to update database.')
            logger.warning("Didn't actually modify database.")
        pass
    logger.info('             ##############   All Done   #################')

if __name__ == "__main__":
    main()
    pass
