#!/usr/bin/env python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sqlalchemy import create_engine
import pymysql as mysql
import pymysql.err as Error
import time
import datetime
from datetime import date
from datetime import timedelta
from datetime import datetime
import configparser

import os
import argparse
import sys

#  global Verbosity, callStack, twoWeeksAgo, filePath
Verbosity = 0
DelOldCsv = False
callStack = []
twoWeeksAgo = (datetime.today() - timedelta(days=14))
filePath = os.path.abspath(os.path.join(os.environ['HOME'], 'GraphingData'))
ServerTimeFromUTC = timedelta(hours=0)
ServerTimeFromUTCSec = 0
haschema = ""
myschema = ""
BeginTime = None       # Number of days to plot

    # make sure "fdata" is defined AS a dataframe; value ignored if csv data is read.
#fdata = pd.DataFrame({ 'A' : 1., 'B' : pd.Timestamp('20130102'), 'C' : pd.Series(1,index=list(range(4)),dtype='float32') })

def makeQuery(dataName, tableName, timeField='time', databaseName=None):
    global myschema
    callStack.append('makeQuery')
    if databaseName is None: databaseName = myschema
    query = "SELECT {timeField} AS 'Time', value AS '{dataName}' \
    FROM `{databaseName}`.`{tableName}` \
    WHERE {timeField} > '%s' \
    ORDER BY {timeField}".format(timeField=timeField, dataName=dataName, tableName=tableName, databaseName=databaseName)
    if Verbosity >= 2: print(callStack, "generated query is: ", query)
    callStack.pop()
    return query

def GetData(DBConn, fileName, query, beginDate, dataTimeOffsetUTC=timedelta(0)):
    """
        DBConn              <connection>    is the database connection object.
        fileName            <string>        is the file name of a CSV file containing previously retrieved data
                                relative to global filePath.
        query               <string>        is an SQL query to retrieve the data, with %s where the begin date goes.
        beginDate           <datetime>      is the DATE of the beginning of the data to retrieve in SERVER local time.
        dataTimeOffsetUTC   <timedelta>     is the amount to adjust beginDate for selecting new data.
                                Add this number to a UTC time to get a corresponding time in the DATABASE.
                                Subtract this number (of hours) from a database time to get UTC.

        1)  Function reads data from the CSV file if it exists, adjusts beginDate to the
        end of the data that was read from CSV so that the SQL query can read only data that
        was not previously read.  (But only if there is more than 20 minutes unread data.)

        2)  The query MUST have a WHERE clause like: " AND {timeField} > '%s'"
        the {timeField} is the database column that retrieves the time data.
        The beginDate is adjusted by use of dataTimeOffsetUTC so that what gets
        filled into the query is in the same time zone as the native data in the database.
        This is to simplify the computations in the WHERE clause.

        3)  The query should retrieve a "Time" field which will be used as an "index" into the
        retrieved DataFrame (in Pandas lingo).  This time data should be adjusted to be in
        the SERVER's local timezone:  daylight saving time or standard time as appropriate to
        the date/time the data is retrieved.  Glitches when transitioning to/from DST are ignored.

        4)  beginDate is a DATE value on entry; we don't worry about time zones when considering the
        beginning of data on the graph.  We use this value to prune the beginning of data
        retrieved from the CSV file.  When used to retrieve DATABASE data, it is converted to the
        same time zone as the {timeField}; not necessarily the timezone of the retrieved data -- see above.

        5)  beginDate is a "datetime" value when used to retrieve SQL data.  See paragraph 1.
        dataTimeOffsetUTC input parameter is used with global ServerTimeFromUTC to determine this value.
        beginDate from the CSV file is in SERVER local time.  Subtract ServerTimeFromUTC from CSV timestamp
        time to get equivalent UTC time.  Then add dataTimeOffsetUTC to get to DATABASE time zone.

        For example:  "creation" vaules in homeassistant database tables are stored in UTC.  The timestamp
        values from the database have ServerTimeFromUTC added to them to get SERVER local times.  For the
        WHERE clause, ServerTimeFromUTC is subtracted from the CSV time, and dataTimeOffsetUTC=0 is added.

        Another example:  Time in the FreezeProtection table in RC is a "timestamp" value, which returns
        time values in the SERVER timezone; the CSV times are appropriate.  For the WHERE clause beginDate,
        ServerTimeFromUTC=-8 is subtracted from the CSV time, and dataTimeOffsetUTC=-8 is added.

        Another example:???
    """
    global Verbosity, callStack, filePath
    callStack.append('GetData')
    if Verbosity >= 2: print(callStack, 'call args beginDate = ', beginDate, ' dataTimeOffsetUTC = ', dataTimeOffsetUTC)
    slicer = 'index > "%s"'%(beginDate + dataTimeOffsetUTC).isoformat()     # pandas "query" to remove old data FROM csv data
    if Verbosity >= 1: print(callStack, 'slicer = ', slicer)
    theFile = os.path.join(filePath, fileName)
    if Verbosity >= 1: print(callStack, 'theFile: ', theFile)
    CSVdataRead = False     # flag is true if we read csv data
    if  os.path.exists(theFile):
        if DelOldCsv:
            os.remove(theFile)
            if Verbosity >= 1: print(callStack, 'CSV file deleted.')
        else:
            fdata = pd.read_csv(theFile, index_col=0, parse_dates=True)
            if Verbosity >= 2: print(callStack, 'Num Points from CSV = ', fdata.size)
            if (fdata.size > 0) and (fdata.index[0] <= beginDate):
                beginDate = fdata.index[-1]
                if Verbosity >= 2: print(callStack, 'Last CSV time = new beginDate = ', beginDate)
                if Verbosity >= 3: print(callStack, 'CSVdata tail:\n', fdata.tail())
                if Verbosity >= 4: print(callStack, 'CSVdata dtypes:\n', fdata.dtypes)
                if Verbosity >= 4: print(callStack, 'CSVdata columns:\n', fdata.columns)
                if Verbosity >= 4: print(callStack, 'CSVdata index:\n', fdata.index)
                CSVdataRead = True
            elif (Verbosity >= 1) and (fdata.size <= 0):
                print(callStack, "CSV file exists but has no data.") 
            elif (Verbosity >= 1) and (fdata.size > 0) and (fdata.index[0] > beginDate):
                print(callStack, "CSV data all more recent than desired data; ignore it.")
            else:
                pass
    else:
        if Verbosity >= 2: print(callStack, 'CSV file does not exist.')
        pass
    beginDate = beginDate - ServerTimeFromUTC + dataTimeOffsetUTC
    if Verbosity >= 2:
        print(callStack, 'beginDate after CSV modified for SQL = ', beginDate)
        print(callStack, "Comparing: now UTC time:", datetime.utcnow(), "and UTC data time:", (beginDate - dataTimeOffsetUTC))
    if (not CSVdataRead) or (datetime.utcnow() - beginDate + dataTimeOffsetUTC) > timedelta(minutes=20):
        myQuery = query%beginDate.isoformat()
        if Verbosity >= 1: print(callStack, 'SQL query: ', myQuery)
        data = pd.read_sql_query(myQuery, DBConn, index_col='Time')
        if data.index.size != 0:
                # Have SQL data
            if Verbosity >= 2: print(callStack, 'Num Points from SQL = ', data.index.size)
            if Verbosity >= 3: print(callStack, 'sql data head:\n', data.head())
            if Verbosity >= 3: print(callStack, 'sql data tail:\n', data.tail())
            if Verbosity >= 4: print(callStack, 'sql data dtypes:\n', data.dtypes)
            if Verbosity >= 4: print(callStack, 'sql data columns:\n', data.columns)
            if Verbosity >= 4: print(callStack, 'sql data index:\n', data.index)
            if CSVdataRead:
                #  Have SQL data and have CSV data, put them together
                data =  fdata.append(data)
                if Verbosity >= 3: print(callStack, 'appended data tail:\n', data.tail())
                if Verbosity >= 4: print(callStack, 'appended data dtypes:\n', data.dtypes)
                if Verbosity >= 4: print(callStack, 'appended data columns:\n', data.columns)
                if Verbosity >= 4: print(callStack, 'appended data index:\n', data.index)
                pass
            else:
                if Verbosity >= 2: print(callStack, 'No CSV data to which to append SQL data.')
                pass    # No CSV data in fdata; SQL data in data
        else:
            # No SQL data
            if Verbosity >= 2: print(callStack, 'No Sql data read.')
            if CSVdataRead:
                # Have CSV data, no SQL data; copy CSV data to output dataFrame
                data = fdata
            else:
                if Verbosity >= 2: print(callStack, 'No CSV data AND no SQL data!!')
                pass    # No CSV data, no SQL data:  punt??
            pass
    else:
        if Verbosity >= 2:
            print(callStack, "CSV data is recent enough; don't query database. ")
            print(callStack, "now", datetime.utcnow(), "beginDate", beginDate, "diff", (datetime.utcnow() - beginDate))
        data = fdata
        pass

    # Only save two weeks of data in the CSV file
    data.query('index > "%s"'%(twoWeeksAgo + dataTimeOffsetUTC).isoformat()).to_csv(theFile, index='Time')
    callStack.pop()
    # in "context" of calling function
    tag = os.path.splitext(fileName)[0]
    if Verbosity >= 3: print(callStack, tag, 'head:\n', data.head())
    if Verbosity >= 3: print(callStack, tag, 'tail:\n', data.tail())
    if Verbosity >= 4: print(callStack, tag, 'dtypes:\n', data.dtypes)
    if Verbosity >= 4: print(callStack, tag, 'columns:\n', data.columns)
    if Verbosity >= 4: print(callStack, tag, 'index:\n', data.index)

    return data.query(slicer)       # return data from beginDate to  present

def ShowRCPower(DBConn):
    global Verbosity, callStack, filePath, ServerTimeFromUTC
    callStack.append('ShowRCPower')
    ###############################  POWER  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Power')
    ax1.set_ylabel('Watts')
    maxTime = 0             # maxTime is used to extend the LR Light data to the end of other data
    plt.set_cmap('Dark2')

    if Verbosity >= 1: print("\n", callStack, "          ----------  HOUSE POWER ----------")
    query = "SELECT {timeField} AS 'Time', \
        HousePowerW AS 'House' \
        FROM `{schema}`.`MeterData` WHERE \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, "House Power SQL: ", query)
    data = GetData(DBConn, 'HousePower.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  HUMIDIFIER POWER ----------")
    query = makeQuery(timeField='time', dataName='Humidifier', tableName='humidifier_power')
    if Verbosity >= 1: print(callStack, "Humidifier power SQL: ", query)
    data = GetData(DBConn, 'HumidifierPower.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  FRIDGE POWER ----------")
    query = makeQuery(timeField='time', dataName='Refrigerator', tableName='fridge_power')
    if Verbosity >= 1: print(callStack, "Fridge Power SQL: ", query)
    data = GetData(DBConn, 'FridgePower.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  A/C POWER ----------")
    query = makeQuery(timeField='time', dataName='A/C Power', tableName='ac_power')
    if Verbosity >= 1: print(callStack, "AC Power SQL: ", query)
    data = GetData(DBConn, 'ACPower.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LR LIGHT POWER ----------")
    query = makeQuery(timeField='time', dataName='LR Light', tableName='lrlight_power')
    if Verbosity >= 1: print(callStack, "LR Light SQL: ", query)
    data = GetData(DBConn, 'LRLight.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
        data = pd.concat([data, pd.DataFrame({'LR Light': [data['LR Light'][-1]]}, index=[maxTime])])
        data.plot(ax=ax1, drawstyle="steps-post")
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowRCLaundry(DBConn):
    global Verbosity, callStack, filePath
    #############    Laundry Trap    #########
    callStack.append('ShowRCLaundry')
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    fig = plt.figure(figsize=[15, 5])   #  Define a figure and set its size in inches.
    ax1 = fig.add_subplot(1, 1, 1)      #  Get reference to axes for labeling
    ax1.set_ylabel('°F')
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Laundry Trap')

    if Verbosity >= 1: print("\n", callStack, "          ----------  LAUNDRY TRAP ----------")
    query = "SELECT {timeField} AS 'Time', \
        TrapTemperature*9/5+32 AS 'Trap', \
        HotWaterValveTemp*9/5+32 AS 'HW',\
        ColdWaterValveTemp*9/5+32 AS 'CW', \
        (1-HotWaterValveOFF)*10+20 AS 'HW Valve', \
        (1-ColdWaterValveOFF)*10+15 AS 'CW Valve' \
        FROM `{schema}`.`FreezeProtection` \
        WHERE {timeField} > '%s' \
        ORDER BY {timeField}".format(timeField='CollectionTime', schema=myschema)
    if Verbosity >= 1: print(callStack, 'Laundry query:\n', query)
    data = GetData(DBConn, 'LaundryTrap.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowRCSolar(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowRCSolar')
    ###############################  Solar Energy  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    #  Setup the figure with two y axes
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Solar')
    ax2 = ax1.twinx()  # instantiate a second axes that shares the same x-axis
    plt.set_cmap('Dark2')

    if Verbosity >= 1: print("\n", callStack, "          ----------  NORTH SOLAR ----------")
    query = "SELECT {timeField} AS 'Time', OutWattsNow AS 'North Array' \
        FROM `{schema}`.`SolarEnergy` WHERE Name = 'North Array' AND \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, 'North Arrray query: ', query)
    data = GetData(DBConn, 'NorthArray.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax1.set_ylabel('Watts')  # we already handled the x-label with ax1
    ax1.legend(loc=2)

    if Verbosity >= 1: print("\n", callStack, "          ----------  SOUTH SOLAR ----------")
    query = "SELECT {timeField} AS 'Time', OutWattsNow AS 'South Array' \
        FROM `{schema}`.`SolarEnergy` WHERE Name = 'South Array' AND \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, 'South Arrray query: ', query)
    data = GetData(DBConn, 'SouthArray.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax1.set_ylabel('Watts')  # we already handled the x-label with ax1

    if Verbosity >= 1: print("\n", callStack, "          ----------  SOLAR RADIATION ----------")
    query = "SELECT {timeField} AS 'Time', SolarRad FROM `{schema}`.`Weather` \
        WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, 'SolarRad query: ', query)
    data = GetData(DBConn, 'SolarRad.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    ax2.set_ylabel('W/m^2', color='tab:red')  # we already handled the x-label with ax1
    ax2.tick_params('y', colors='tab:red')
    if len(data) > 0:
        data.plot(ax=ax2, color='tab:red')
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax2.legend(loc=5)
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowRCWater(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowRCWater')
    ###############################  Water  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    #  Setup the figure with two y axes
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Water')
    ax2 = ax1.twinx()  # instantiate a second axes that shares the same x-axis
    plt.set_cmap('Dark2')

#
#   Two queries since plotted on different axes.
#
    if Verbosity >= 1: print("\n", callStack, "          ----------  GALLONS PER MIN   ----------")
    query = "SELECT {timeField} AS 'Time', \
        GPM AS 'Gallons/min' \
        FROM `{schema}`.`MeterData` WHERE \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, 'GPM query: ', query)
    data = GetData(DBConn, 'GPM.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax1.set_ylabel('Gallons Per Minute')  # we already handled the x-label with ax1

    if Verbosity >= 1: print("\n", callStack, "          ----------  WATER SYS POWER   ----------")
    query = "SELECT {timeField} AS 'Time', \
        AvgWaterPowerW AS 'Well Power' \
        FROM `{schema}`.`MeterData` WHERE \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, 'WellPower query: ', query)
    data = GetData(DBConn, 'WellPower.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    ax2.set_ylabel('Watts', color='tab:red')  # we already handled the x-label with ax1
    ax2.tick_params('y', colors='tab:red')
    if len(data) > 0:
        data.plot(ax=ax2, color='tab:red')
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax2.legend(loc=5)
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowRCTemps(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowRCTemps')
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    ###############################  Temperatures  ############################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Temperatures')
    ax1.set_ylabel('°F')
    plt.set_cmap('Dark2')

    if Verbosity >= 1: print("\n", callStack, "          ----------  OUTSIDE / INSIDE TEMP  ----------")
    query = "SELECT {timeField} AS 'Time', OutsideTemp, InsideTemp AS 'Computer' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, "Out, In Temp SQL: ", query)
    data = GetData(DBConn, 'RcWxTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  THERMOSTAT TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Thermostat', tableName='thermostat_temp')
    if Verbosity >= 1: print(callStack, "Thermostat temp SQL: ", query)
    data = GetData(DBConn, 'ThermostatTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  DINING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_temp')
    if Verbosity >= 1: print(callStack, "Dining temp SQL: ", query)
    data = GetData(DBConn, 'DiningTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  GUEST TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_temp')
    if Verbosity >= 1: print(callStack, "Guest temp SQL: ", query)
    data = GetData(DBConn, 'GuestTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  KITCHEN TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_temp')
    if Verbosity >= 1: print(callStack, "Kitchen temp SQL: ", query)
    data = GetData(DBConn, 'KitchenTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MASTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_temp')
    if Verbosity >= 1: print(callStack, "Master temp SQL: ", query)
    data = GetData(DBConn, 'MasterTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LIVING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_temp')
    if Verbosity >= 1: print(callStack, "Living temp SQL: ", query)
    data = GetData(DBConn, 'LivingTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowRCHums(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowRCHums')
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    ###############################  Humidities  ############################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Humidities')
    ax1.set_ylabel('% HUMIDITY')
    plt.set_cmap('Dark2')

    if Verbosity >= 1: print("\n", callStack, "          ----------  OUTSIDE / INSIDE HUMIDITY ----------")
    query = "SELECT {timeField} AS 'Time', OutsideHumidity AS 'Outside', InsideHumidity AS 'Computer' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, "Out, In Hum SQL: ", query)
    data = GetData(DBConn, 'RcWxHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  THERMOSTAT HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Thermostat', tableName='thermostat_hum')
    if Verbosity >= 1: print(callStack, "Thermostat Hum SQL: ", query)
    data = GetData(DBConn, 'ThermostatHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  DINING HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_hum')
    if Verbosity >= 1: print(callStack, "Dining Hum SQL: ", query)
    data = GetData(DBConn, 'DiningHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  GUEST HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_hum')
    if Verbosity >= 1: print(callStack, "Guest Hum SQL: ", query)
    data = GetData(DBConn, 'GuestHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  KITCHEN HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_hum')
    if Verbosity >= 1: print(callStack, "Kitchen Hum SQL: ", query)
    data = GetData(DBConn, 'KitchenHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MASTER HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_hum')
    if Verbosity >= 1: print(callStack, "Master Hum SQL: ", query)
    data = GetData(DBConn, 'MasterHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LIVING HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_hum')
    if Verbosity >= 1: print(callStack, "Living Hum SQL: ", query)
    data = GetData(DBConn, 'LivingHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowRCHeaters(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowRCHeaters')
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    ###############################  HEATERS  ############################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Heaters')
    ax1.set_ylabel('°F Temperature')
    ax2 = ax1.twinx()  # instantiate a second axes that shares the same x-axis
    ax2.set_ylabel('Watts')  # we already handled the x-label with ax1
    # ax2.tick_params('y')
    plt.set_cmap('Dark2')

    if Verbosity >= 1: print("\n", callStack, "          ----------  COMPUTER TEMP ----------")
    query = "SELECT {timeField} AS 'Time', InsideTemp AS 'Computer' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    if Verbosity >= 1: print(callStack, "Computer Temp SQL: ", query)
    data = GetData(DBConn, 'ComputerTemp.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  DINING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_temp')
    if Verbosity >= 1: print(callStack, "Dining temp SQL: ", query)
    data = GetData(DBConn, 'DiningTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  GUEST TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_temp')
    if Verbosity >= 1: print(callStack, "Guest temp SQL: ", query)
    data = GetData(DBConn, 'GuestTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  KITCHEN TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_temp')
    if Verbosity >= 1: print(callStack, "Kitchen temp SQL: ", query)
    data = GetData(DBConn, 'KitchenTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MASTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_temp')
    if Verbosity >= 1: print(callStack, "Master temp SQL: ", query)
    data = GetData(DBConn, 'MasterTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LIVING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_temp')
    if Verbosity >= 1: print(callStack, "Living temp SQL: ", query)
    data = GetData(DBConn, 'LivingTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  COMPUTER HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Computer', tableName='computer_heater_power')
    if Verbosity >= 1: print(callStack, "Dining H Power SQL: ", query)
    data = GetData(DBConn, 'ComputerHeaterWatts.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  DINING HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_heater_power')
    if Verbosity >= 1: print(callStack, "Dining H Power SQL: ", query)
    data = GetData(DBConn, 'DiningHeaterWatts.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  GUEST HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_heater_power')
    if Verbosity >= 1: print(callStack, "Guest H Power SQL: ", query)
    data = GetData(DBConn, 'GuestHeaterWatts.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  KITCHEN HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_heater_power')
    if Verbosity >= 1: print(callStack, "Kitchen H Power SQL: ", query)
    data = GetData(DBConn, 'KitchenHeaterWatts.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MASTER HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_heater_power')
    if Verbosity >= 1: print(callStack, "Master H Power SQL: ", query)
    data = GetData(DBConn, 'MasterHeaterWatts.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LIVING HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_heater_power')
    if Verbosity >= 1: print(callStack, "Living H Power SQL: ", query)
    data = GetData(DBConn, 'LivingHeaterWatts.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    # ax2.legend()
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowSSFurnace(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowSSFurnace')
    ###############################  SS Furnace  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    fig = plt.figure(figsize=[15, 5])   #  Define a figure and set its size in inches.
    ax1 = fig.add_subplot(1, 1, 1)      #  Get reference to axes for labeling
  # ax1.set_ylabel('°F')
    ax1.set_xlabel('Date/time')
    ax1.set_title('Steamboat Furnace')


    if Verbosity >= 1: print("\n", callStack, "          ----------  STEAMBOAT FURNACE ----------")
    query = "SELECT {timeField} AS 'Time', \
    round(json_value(message, '$.Temperature'), 1) AS 'Temp', \
    round(json_value(message, '$.Humidity'), 1) AS 'Humidity', \
    (json_value(message, '$.Burner') = 'ON')*20+20 AS 'Furnace', \
    (json_value(message, '$.MotionDetected') = 'ON')*10+15 AS 'Motion' \
    FROM `{schema}`.`mqttmessages` WHERE topic='dc4f220da32f/data' \
    AND {timeField}  > '%s' \
    AND {timeField}  < now(6) /* eliminate spurious records with times too late */ \
    AND json_value(message, '$.Temperature') < 150 \
    AND json_value(message, '$.Humidity') < 110 \
    ORDER BY {timeField}".format(timeField='RecTime', schema = myschema)
    if Verbosity >= 1: print(callStack,' SQL query:\n', query)
    data = GetData(DBConn, 'SSFurnace.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowSSTemps(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowSSTemps')
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    ###############################  SS Temperatures  ##########################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Steamboat Temperatures')
    ax1.set_ylabel('°F')

    if Verbosity >= 1: print("\n", callStack, "          ----------  OUTSIDE/INSIDE TEMPS ----------")
    query = "SELECT {timeField} AS 'Time', \
    tempf AS 'Outside', \
    tempinf AS 'Hallway' \
    FROM `{schema}`.`weather` WHERE {timeField}  > '%s' \
    ORDER BY {timeField}".format(timeField='date', schema = myschema)
    if Verbosity >= 1: print(callStack,' SQL query:\n', query)
    data = GetData(DBConn, 'SSWeatherTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MASTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_temp', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Master temp SQL: ", query)
    data = GetData(DBConn, 'SSMasterTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LIVING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_temp', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Living temp SQL: ", query)
    data = GetData(DBConn, 'SSLivingTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  COMPUTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Computer', tableName='computer_temp', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Computer temp SQL: ", query)
    data = GetData(DBConn, 'SSComputerTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  KITCHEN TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_temp', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Kitchen temp SQL: ", query)
    data = GetData(DBConn, 'SSKitchenTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MUD TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Mud', tableName='mud_temp', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Mud temp SQL: ", query)
    data = GetData(DBConn, 'SSMudTemps.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def ShowSSHums(DBConn):
    global Verbosity, callStack, filePath
    callStack.append('ShowSSHums')
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    beginDate = BeginTime
    ###############################  SS Humidities    ##########################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Steamboat Humidities')
    ax1.set_ylabel('% HUMIDITY')

    if Verbosity >= 1: print("\n", callStack, "          ----------  OUTSIDE/INSIDE HUMIDITIES ----------")
    query = "SELECT {timeField} AS 'Time', \
    humidity AS 'Outside', \
    humidityin AS 'Hallway' \
    FROM `{schema}`.`weather` WHERE {timeField}  > '%s' \
    ORDER BY {timeField}".format(timeField='date', schema = myschema)
    if Verbosity >= 1: print(callStack,' SQL query:\n', query)
    data = GetData(DBConn, 'SSWeatherHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MASTER HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_hum', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Master Hum SQL: ", query)
    data = GetData(DBConn, 'SSMasterHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  LIVING HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_hum', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Living Hum SQL: ", query)
    data = GetData(DBConn, 'SSLivingHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  COMPUTER HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Computer', tableName='computer_hum', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Computer Hum SQL: ", query)
    data = GetData(DBConn, 'SSComputerHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  KITCHEN HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_hum', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Kitchen Hum SQL: ", query)
    data = GetData(DBConn, 'SSKitchenHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    if Verbosity >= 1: print("\n", callStack, "          ----------  MUD HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Mud', tableName='mud_hum', databaseName=myschema)
    if Verbosity >= 1: print(callStack, "Mud Hum SQL: ", query)
    data = GetData(DBConn, 'SSMudHums.csv', query, beginDate, dataTimeOffsetUTC=ServerTimeFromUTC)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        if Verbosity >= 1: print(callStack, "No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)
    callStack.pop()

def main():
    global Verbosity, callStack, filePath, ServerTimeFromUTC, twoWeeksAgo, ServerTimeFromUTCSec, DelOldCsv, haschema, myschema
    global BeginTime
    callStack.append('main')
    RCGraphs = {'solar', 'laundry', 'hums', 'temps', 'water', 'power', 'heaters'}
    SSGraphs = {'Furnace', 'Temps', 'Hums'}
    parser = argparse.ArgumentParser(description = 'Display graphs of home parameters.\nDefaults to show all.')
    parser.add_argument("-d", "--days", dest="days", action="store", help="Number of days of data to plot", default=14)
    parser.add_argument("-l", "--laundry", dest="laundry", action="store_true", help="Show Ridgecrest Laundry Trap graph.")
    parser.add_argument("-s", "--solar", dest="solar", action="store_true", help="Show Ridgecrest Solar graph.")
    parser.add_argument("-u", "--humidities", dest="hums", action="store_true", help="Show Ridgecrest Humidities graph.")
    parser.add_argument("-t", "--temperatures", dest="temps", action="store_true", help="Show Ridgecrest Temperatures graph.")
    parser.add_argument("-w", "--water", dest="water", action="store_true", help="Show Ridgecrest Water graph.")
    parser.add_argument("-e", "--heaters", dest="heaters", action="store_true", help="Show Ridgecrest Heaters graph.")
    parser.add_argument("-p", "--power", dest="power", action="store_true", help="Show Ridgecrest Power graph.")
    parser.add_argument("-F", "--SSFurnace", dest="Furnace", action="store_true", help="Show Steamboat Furnace graph.")
    parser.add_argument("-H", "--SSHumidities", dest="Hums", action="store_true", help="Show Steamboat Humidities graph.")
    parser.add_argument("-T", "--SSTemperatures", dest="Temps", action="store_true", help="Show Steamboat Temperatures graph.")
    parser.add_argument("-v", "--verbosity", dest="verbosity", action="count", help="increase output verbosity", default=0)
    parser.add_argument("--DeleteOldCSVData", dest="DeleteOld", action="store_true", help="Delete any existing CSV data for selected graphs before retrieving new.")
    args = parser.parse_args()
    Verbosity = args.verbosity
    DelOldCsv = args.DeleteOld
    numDays = float(args.days)

    command_line_args = {k for k, v in vars(args).items() if v}
    command_line_args.discard('verbosity')      # verbosity not a plotting item
    command_line_args.discard('DeleteOldCSVData')      # DeleteOldCSVData not a plotting item
    command_line_args.discard('days')      # number of days is not a plotting item

    if len(command_line_args) == 0:     # no options given, provide a default set.
        command_line_args = SSGraphs.union(RCGraphs)        # all graphs
    if Verbosity >= 1:         print(callStack, command_line_args)
    if Verbosity >= 3:         print(callStack, 'Command line contains RC graphs: ', not RCGraphs.isdisjoint(command_line_args))
    if Verbosity >= 3:         print(callStack, 'Command line contains SS graphs: ', not SSGraphs.isdisjoint(command_line_args))

    config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
    config.read('secrets.ini')
    cfgSection = os.environ['HOST']+"/"+os.path.basename(sys.argv[0])
    if Verbosity >= 2: print(callStack, "INI file cofig section is:", cfgSection)
    cfg = config[cfgSection]

    if  not RCGraphs.isdisjoint(command_line_args):
        user = cfg['database_reader_user']
        pwd  = cfg['database_reader_password']
        host = cfg['rc_database_host']
        port = cfg['rc_database_port']
        haschema = cfg['rc_ha_schema']
        myschema = cfg['rc_my_schema']
        if Verbosity >= 2:
            print(callStack, "RC user", user)
            print(callStack, "RC pwd", pwd)
            print(callStack, "RC host", host)
            print(callStack, "RC port", port)
            print(callStack, "RC haschema", haschema)
            print(callStack, "RC myschema", myschema)

        connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=haschema)
        if Verbosity >= 1: print(callStack, "RC database connection string:", connstr)
        Eng = create_engine(connstr, echo = True if Verbosity>=2 else False)
        if Verbosity >= 1: print(callStack, Eng)
        with Eng.connect() as conn, conn.begin():
            result = conn.execute("select timestampdiff(hour, utc_timestamp(), now());")
            for row in result:
                ServerTimeFromUTC = timedelta(hours=row[0])
                ServerTimeFromUTCSec = ServerTimeFromUTC.days*86400+ServerTimeFromUTC.seconds
            twoWeeksAgo = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            BeginTime = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            if Verbosity >= 1:
                print(callStack, "RC Server time offset from UTC: ", ServerTimeFromUTC)
                print(callStack, "RC Server time offset from UTC (seconds): ", ServerTimeFromUTCSec)
                print(callStack, "RC twoWeeksAgo: ", twoWeeksAgo)
            if 'laundry'    in command_line_args:   ShowRCLaundry(conn)
            if 'solar'      in command_line_args:   ShowRCSolar(conn)
            if 'temps'      in command_line_args:   ShowRCTemps(conn)
            if 'hums'       in command_line_args:   ShowRCHums(conn)
            if 'heaters'    in command_line_args:   ShowRCHeaters(conn)
            if 'water'      in command_line_args:   ShowRCWater(conn)
            if 'power'      in command_line_args:   ShowRCPower(conn)

    if  not SSGraphs.isdisjoint(command_line_args):
        user = cfg['database_reader_user']
        pwd  = cfg['database_reader_password']
        host = cfg['ss_database_host']
        port = cfg['ss_database_port']
        haschema = cfg['ss_ha_schema']
        myschema = cfg['ss_my_schema']
        if Verbosity >= 2:
            print(callStack, "SS user", user)
            print(callStack, "SS pwd", pwd)
            print(callStack, "SS host", host)
            print(callStack, "SS port", port)
            print(callStack, "SS haschema", haschema)
            print(callStack, "SS myschema", myschema)

        connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=haschema)
        if Verbosity >= 1: print(callStack, "SS database connection string:", connstr)
        Eng = create_engine(connstr, echo = True if Verbosity>=2 else False)
        if Verbosity >= 1: print(callStack, Eng)
        with Eng.connect() as conn, conn.begin():
            result = conn.execute("select timestampdiff(hour, utc_timestamp(), now());")
            for row in result:
                ServerTimeFromUTC = timedelta(hours=row[0])
                ServerTimeFromUTCSec = ServerTimeFromUTC.days*86400+ServerTimeFromUTC.seconds
            twoWeeksAgo = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            BeginTime = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            if Verbosity >= 1:
                print(callStack, "SS Server time offset from UTC: ", ServerTimeFromUTC)
                print(callStack, "SS Server time offset from UTC (seconds): ", ServerTimeFromUTCSec)
                print(callStack, "SS twoWeeksAgo: ", twoWeeksAgo)
            if 'Furnace' in command_line_args:      ShowSSFurnace(conn)
            if 'Temps' in command_line_args:        ShowSSTemps(conn)
            if 'Hums' in command_line_args:         ShowSSHums(conn)

    callStack.pop()

if __name__ == "__main__":
    main()
    pass
