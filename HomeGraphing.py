#!/usr/bin/env python3

import pandas as pd
import numpy as np
from bokeh.layouts import gridplot
from bokeh.plotting import figure, show, output_file
from bokeh.models import ColumnDataSource, HoverTool, Legend, LegendItem
from bokeh.models import Range1d, DataRange1d, LinearAxis
from bokeh.resources import Resources
from bokeh.embed import file_html
from bokeh.util.browser import view
from bokeh.models.formatters import DatetimeTickFormatter
# from bokeh.models.tickers import DatetimeTicker

import math
from sqlalchemy import create_engine
import pymysql as mysql
import pymysql.err as Error
import time
import datetime
from datetime import date
from datetime import timedelta
from datetime import datetime
import os
import argparse
import sys
import configparser
import logging
import logging.config
import logging.handlers
import json
import myPalette
import itertools
from GraphDefinitions import GetGraphDefs
from myPalette import Palette

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
                logFileName = os.path.join(logPath, config_dict['handlers'][p]['filename'])
                config_dict['handlers'][p]['filename'] = logFileName
        logging.config.dictConfig(config_dict)
    except Exception as e:
        print("loading logger config from file failed.")
        print(e)
        pass

logger = logging.getLogger(__name__)
logger.info('logger name is: "%s"', logger.name)

DBConn = None
DBCursor = None
Topics = []    # default topics to subscribe
mqtt_msg_table = None
RequiredConfigParams = frozenset((
    'ss_ha_schema'
  , 'ss_my_schema'
  , 'ss_database_host'
  , 'ss_database_port'
  , 'rc_ha_schema'
  , 'rc_my_schema'
  , 'rc_database_host'
  , 'rc_database_port'
  , 'database_reader_user'
  , 'database_reader_password'
))

filePath = os.path.abspath(os.path.expandvars('$HOME/GraphingData'))
if not os.path.isdir(filePath):
    os.makedirs(filePath, exist_ok=True)

def GetConfigFilePath():
    fp = os.path.join(ProgPath, 'secrets.ini')
    if not os.path.isfile(fp):
        fp = os.environ['PrivateConfig']
        if not os.path.isfile(fp):
            logger.error('No configuration file found: %s', fp)
            sys.exit(1)
    logger.info('Using configuration file at: %s', fp)
    return fp


#  global twoWeeksAgo, filePath
DelOldCsv = False
LocalDataOnly = False
SaveCSVData = True  # Flags GetData function to save back to the CSV data file.
BeginTime = None       # Number of days to plot
DBHostDict = dict()
DatabaseReadDelta = 20

def GetData(fileName, query = None, dataTimeOffsetUTC = None, hostParams = dict()):
    """
        fileName            <string>        is the file name of a CSV file containing previously retrieved data
                                relative to global filePath.
        DBConn              <connection>    is the database connection object.
        query               <string>        is an SQL query to retrieve the data, with %s where the begin date goes.
        dataTimeOffsetUTC   <timedelta>     is the amount to adjust beginDate for selecting new data.
                                Add this number to a UTC time to get a corresponding time in the DATABASE.
                                Subtract this number (of hours) from a database time to get UTC.

        1)  Function reads data from the CSV file if it exists, adjusts beginDate to the
        end of the data that was read from CSV so that the SQL query can read only data that
        was not previously read.  (But only if there is more than DatabaseReadDelta minutes unread data.)

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

        beginDate           <datetime>      is the DATE of the beginning of the data to retrieve in SERVER local time.
    """
    prevLogLevel = logger.getEffectiveLevel()
    # logger.setLevel('WARNING')

    if (len(hostParams) == 0) or (dataTimeOffsetUTC is None) or LocalDataOnly: # no host params, don't try to do database stuff
        logger.warning('hostParams dict is empty, or no dataTimeOffsetUTC given.  Do not access database.')
        query = None

    #  What to do if hostParams is empty??????????????? (Shouldn't happen)
    beginDate = hostParams['BeginTime']
    twoWeeksAgo = hostParams['twoWeeksAgo']
    # use these commented out lines if the DBConn doesn't survive being in the hostParams dict.
    # DBConn = hostParams['DBEngine'].connect()
    # DBConn.begin()
    DBConn = hostParams['conn']

    slicer = 'index > "%s"'%(beginDate + dataTimeOffsetUTC).isoformat()     # pandas "query" to remove old data FROM csv data
    logger.info('slicer = %s', slicer)

    SQLbeginDate = beginDate        # initial value; changed later if CSV data read

    logger.debug('call args -- fileName: %s, DBConn: %s, query: %s', fileName, DBConn, query)
    logger.debug('beginDate = %s dataTimeOffsetUTC = %s', beginDate, dataTimeOffsetUTC)
    theFile = os.path.join(filePath, fileName)
    logger.info('theFile: %s', theFile)
    CSVdataRead = False     # flag is true if we read csv data
    if  os.path.exists(theFile):
        if DelOldCsv:
            os.remove(theFile)
            logger.info('CSV file deleted.')
            fdata = None
        else:
            fdata = pd.read_csv(theFile, index_col=0, parse_dates=True)
            logger.debug('Num Points from CSV = %s', fdata.size)
            if (fdata.size <= 0):
                logger.info("CSV file exists but has no data.")
                fdata = None
            elif (beginDate is not None) and (fdata.index[0] > beginDate):
                logger.debug("CSV data all more recent than desired data; ignore it.")
                fdata = None
            else:
                SQLbeginDate = fdata.index[-1]
                logger.debug('Last CSV time = new beginDate = %s', beginDate)
                logger.debug('CSVdata tail:\n%s', fdata.tail())
                logger.debug('CSVdata dtypes:\n%s', fdata.dtypes)
                logger.debug('CSVdata columns:\n%s', fdata.columns)
                logger.debug('CSVdata index:\n%s', fdata.index)
                CSVdataRead = True
    else:
        logger.warning('CSV file does not exist.')
        fdata = None
        pass
    logger.debug('SQLbeginDate after CSV modified for SQL = %s', SQLbeginDate)
    logger.debug("Comparing: now UTC time: %s and UTC data time: %s", datetime.utcnow(), (SQLbeginDate - dataTimeOffsetUTC))
    if ((not CSVdataRead) or (datetime.utcnow() - SQLbeginDate + dataTimeOffsetUTC) > timedelta(minutes=DatabaseReadDelta)) and DBConn and query:
        logger.debug('SQLbeginDate for creating SQL query %s', SQLbeginDate)
        myQuery = query%SQLbeginDate.isoformat()
        logger.info('SQL query: %s', myQuery)
        data = pd.read_sql_query(myQuery, DBConn, index_col='Time')
        if data.index.size != 0:
                # Have SQL data
            logger.debug('Num Points from SQL = %s', data.index.size)
            logger.debug('sql data head:\n%s', data.head())
            logger.debug('sql data tail:\n%s', data.tail())
            logger.debug('sql data dtypes:\n%s', data.dtypes)
            logger.debug('sql data columns:\n%s', data.columns)
            logger.debug('sql data index:\n%s', data.index)
            if CSVdataRead:
                #  Have SQL data and have CSV data, put them together
                data =  fdata.append(data)
                logger.debug('appended data tail:\n%s', data.tail())
                logger.debug('appended data dtypes:\n%s', data.dtypes)
                logger.debug('appended data columns:\n%s', data.columns)
                logger.debug('appended data index:\n%s', data.index)
                pass
            else:
                logger.debug('No CSV data to which to append SQL data.')
                pass    # No CSV data in fdata; SQL data in data
        else:
            # No SQL data
            logger.debug('No Sql data read.')
            if CSVdataRead:
                # Have CSV data, no SQL data; copy CSV data to output dataFrame
                data = fdata
            else:
                logger.debug('No CSV data AND no SQL data!!')
                pass    # No CSV data, no SQL data:  punt??
            pass
    else:
        if DBConn and query:
            logger.info("CSV data is recent enough; don't query database. ")
            logger.debug("now %s SQLbeginDate %s diff %s", datetime.utcnow(), SQLbeginDate, (datetime.utcnow() - SQLbeginDate))
        elif LocalDataOnly:
            logger.debug('Using local data only; no database data desired.  No SQL data.')
        else:
            logger.debug('No database parameters defined; no SQL data.')
        data = fdata
        pass

    if data is None:
        logger.setLevel(prevLogLevel)
        return data

    # Only save two weeks of data in the CSV file
    if SaveCSVData: data.query('index > "%s"'% twoWeeksAgo.isoformat()).to_csv(theFile, index='Time')

    logger.setLevel(prevLogLevel)
    return data.query(slicer)       # return data from beginDate to  present

def ShowGraph(graphDict):

    if not graphDict['ShowGraph']:
        logger.warning('%s is not shown.', graphDict['GraphTitle'])
        return

    if (len(graphDict['Yaxes']) <= 0) or (len(graphDict['items']) <= 0):
        logger.debug('No axes or no lines defined for graph "%s"', graphDict['GraphTitle'])
        return

    if graphDict['DBHost'] not in DBHostDict.keys():
        logger.warning('Unknown database host "%s" for plot "%s"' % (graphDict['DBHost'], graphDict['GraphTitle']))
        return

    hostItem = DBHostDict[graphDict['DBHost']]

    # Signal that we want to reference local files for html output.
    res = Resources(mode='absolute')

    # output_file(graphDict["outputFile"], title=graphDict['GraphTitle'])

    plot = figure(title=graphDict['GraphTitle']
            , tools="pan,wheel_zoom,box_zoom,reset,save,box_select"
            , x_axis_type='datetime'
            , plot_width=1600, plot_height=800
            , active_drag="box_zoom"
            , active_scroll = "wheel_zoom")
    plot.title.align = "center"
    plot.title.text_font_size = "25px"
    plot.xaxis.axis_label = graphDict['XaxisTitle']
    # plot.xaxis.ticker = DatetimeTicker(num_minor_ticks = 4)
    plot.xaxis.formatter = DatetimeTickFormatter(seconds=["%M:%S"],
                                            minutes=["%R"],
                                            minsec=["%M:%S"],
                                            hours=["%R"],
                                            hourmin = ["%m/%d %R"],
                                            days = ['%m/%d'])
    plot.toolbar.logo = None
    legend = Legend()
    # legend.items = [LegendItem(label="--- Left Axis ---"   , renderers=[])]
    legend.items = []

    #########   Setup Y axes
    ## Colors
    plot.yaxis.visible = False
    extra_y_ranges = {}

    for i in range(len(graphDict['Yaxes'])):
        ya = graphDict['Yaxes'][i]
        eyrName = 'Y%s_axis' % i
        clr = ya['color_map']
        if clr is None: clr = graphDict["graph_color_map"]
        ya["cmap"] = myPalette.Palette(clr, graphDict['max_palette_len'])
        clr = ya['color']
        if clr is None: clr = "black"
        side = ya['location']
        extra_y_ranges[eyrName] = DataRange1d(range_padding = 0.01)
        plot.extra_y_ranges = extra_y_ranges
        plot.add_layout(LinearAxis(
                y_range_name=eyrName,
                axis_label=ya['title'],
                axis_line_color=clr,
                major_label_text_color=clr,
                axis_label_text_color=clr,
                major_tick_line_color=clr,
                minor_tick_line_color=clr
            ), side)


    for i in range(len(graphDict['items'])):
        item = graphDict['items'][i]
        logger.info('--------------  %s  ------------' % item['dataname'])
        ya = graphDict['Yaxes'][item['axisNum']]
        colorGroup = ya['title']
        query = item['query'].format(
              my_schema=hostItem['myschema']
            , ha_schema=hostItem['haschema']
            )
        if item['dataTimeZone'] == 'UTC':
            dataTimeOffsetUTC = 0
        else:
            dataTimeOffsetUTC = hostItem['ServerTimeFromUTC']
        data = GetData(item['datafile'], query, dataTimeOffsetUTC, hostItem)
        if data is None:
            logger.warning('item "%s" of graph "%s" has no data and is skipped.' % (item['dataname'], graphDict['GraphTitle']))
            continue
        else:
            logger.debug('Got %s rows of data.' % data.size)
        data = ColumnDataSource(data)
        logger.debug('data column names are: %s; num rows is:  %s' % (data.column_names, data.to_df().size))
        yRangeName = 'Y%s_axis' % item['axisNum']
        for thisCol in data.column_names[1:]:
            logger.debug('Column "%s" is plotted against y axis: "%s"' % (thisCol, yRangeName))
            itemColor = item["color"]
            if item["color"] is None:
                itemColor = ya['cmap'].nextColor(colorGroup)
            else:
                logger.debug('item color "%s" is defined in the item definition.' % itemColor)
            r = eval('''plot.%s(x=data.column_names[0]
                , y = thisCol
                , source=data
                , color = itemColor, alpha=0.5
                , muted_color = itemColor, muted_alpha=1
                , name = thisCol
                , y_range_name=yRangeName)'''%item['lineType'])
            for (k, v) in item['lineMods'].items():
                s = 'r.%s = %s'%(k, v)
                logger.debug('Executing line mod "%s"' % s)
                exec(s)
            extra_y_ranges[yRangeName].renderers.append(r)
            if item['includeInLegend']: legend.items.append(LegendItem(label=thisCol, renderers=[r]))
    plot.add_layout(legend)
    plot.legend.location = "top_left"
    plot.legend.click_policy = "mute"
    plot.add_tools(HoverTool(
        tooltips=[
              ( '',  '$name' ) # use @{ } for field names with spaces
            , ( '',  '$y{0.0}' ) # use @{ } for field names with spaces
            , ( '',   '@Time{%F %T}'   )
            ],
            formatters={
                'Time' : 'datetime' # use 'datetime' formatter for 'x' field
                                        # use default 'numeral' formatter for other fields
            }))

    # show(plot)
    html = file_html(plot, res, graphDict['GraphTitle'])
    f = open(graphDict["outputFile"], mode='w')
    f.write(html)
    f.close()
    view(graphDict["outputFile"], new='tab')

def main():
    global DelOldCsv, SaveCSVData, DBHostDict, LocalDataOnly, DatabaseReadDelta

    RCGraphs = {'RCSolar', 'RCLaundry', 'RCHums', 'RCTemps', 'RCWater', 'RCPower', 'RCHeaters'}
    SSGraphs = {'SSFurnace', 'SSTemps', 'SSHums', 'SSMotion', 'SSLights'}

    config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
    configFile = GetConfigFilePath()
    configFileDir = os.path.dirname(configFile)
    defaultGraphsDefinitionFile = os.path.join(configFileDir, "AllGraphs.json")

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

    parser = argparse.ArgumentParser(description = 'Display graphs of home parameters.\nDefaults to show all.')
    parser.add_argument("plots", action="append", nargs="*", help="Optional list of plots to generate.")
    parser.add_argument("-d", "--days", dest="days", action="store", help="Number of days of data to plot", default=14)
    parser.add_argument("-l", "--laundry", dest="plots", action="append_const", const="RCLaundry", help="Show Ridgecrest Laundry Trap graph.")
    parser.add_argument("-s", "--solar", dest="plots", action="append_const", const="RCSolar", help="Show Ridgecrest Solar graph.")
    parser.add_argument("-u", "--humidities", dest="plots", action="append_const", const="RCHums", help="Show Ridgecrest Humidities graph.")
    parser.add_argument("-t", "--temperatures", dest="plots", action="append_const", const="RCTemps", help="Show Ridgecrest Temperatures graph.")
    parser.add_argument("-w", "--water", dest="plots", action="append_const", const="RCWater", help="Show Ridgecrest Water graph.")
    parser.add_argument("-e", "--heaters", dest="plots", action="append_const", const="RCHeaters", help="Show Ridgecrest Heaters graph.")
    parser.add_argument("-p", "--power", dest="plots", action="append_const", const="RCPower", help="Show Ridgecrest Power graph.")
    parser.add_argument("-F", "--SSFurnace", dest="plots", action="append_const", const="SSFurnace", help="Show Steamboat Furnace graph.")
    parser.add_argument("-H", "--SSHumidities", dest="plots", action="append_const", const="SSHums", help="Show Steamboat Humidities graph.")
    parser.add_argument("-T", "--SSTemperatures", dest="plots", action="append_const", const="SSTemps", help="Show Steamboat Temperatures graph.")
    parser.add_argument("-L", "--SSLightss", dest="plots", action="append_const", const="SSLights", help="Show Steamboat Lights graph.")
    parser.add_argument("-M", "--SSMotion", dest="plots", action="append_const", const="SSMotion", help="Show Steamboat Motions graph.")
    parser.add_argument("-v", "--verbosity", dest="verbosity", action="count", help="increase output verbosity", default=0)
    parser.add_argument("--LocalDataOnly", dest="LocalOnly", action="store_true", help="Use only locally stored data for graphs; don't access remote databases.")
    parser.add_argument("--DeleteOldCSVData", dest="DeleteOld", action="store_true", help="Delete any existing CSV data for selected graphs before retrieving new.")
    parser.add_argument("--DontSaveCSVData", dest="DontSaveCSVdata", action="store_true", default=False, help="Do NOT save CSV data for selected graphs.")
    parser.add_argument("-g", "--graphs", dest="graphDefs", action="store", help="Name of graph definition file", default=defaultGraphsDefinitionFile)
    parser.add_argument("--DbDelta", dest="DbDelta", action="store", help="Min minutes since last database read", default=DatabaseReadDelta)
    args = parser.parse_args()
    Verbosity = args.verbosity
    DelOldCsv = args.DeleteOld
    SaveCSVData = not args.DontSaveCSVdata
    LocalDataOnly = args.LocalOnly
    numDays = float(args.days)
    DatabaseReadDelta = float(args.DbDelta)

    desired_plots = set()
    logger.debug('There are %s plot items specified on the command line.' % len(args.plots))
    for i in range(len(args.plots)):
        itm = args.plots[i]
        logger.debug('Plots item %s is %s' % (i, itm))
        if len(itm) > 0:
            if isinstance(itm, str):
                logger.debug('plots item is a str: "%s"' % itm)
                desired_plots.add(itm)
            elif isinstance(itm, list):
                logger.debug('plots item is a list')
                for j in itm:
                    desired_plots.add(j)

    logger.debug('Desired plots is: %s'%(desired_plots,))

#    allKnownPlots = SSGraphs.union(RCGraphs)
    GraphDefs = GetGraphDefs(args.graphDefs)

    #  Here we compute some helper fields in the GraphDefs dictionary.
    #  Do this here because we don't want to pollute the GetGraphDefs function
    # with a bunch of imports and code it doesn't need to do its job.
    DBHosts = set()
    gdks = set(GraphDefs.keys())
    logger.debug('Graphs defined in the graph defs file are: %s' % gdks)
    if len(desired_plots) > 0:
        plotlist = list(desired_plots)
        for p in plotlist:
            if p not in gdks:
                logger.warning('Plot: "%s" is unknown, and will be ignored.' % p)
                desired_plots.remove(p)
    if len(desired_plots) == 0:     # no options given, and no config graphs, provide a default set.
        desired_plots = gdks        # all graphs
        logger.debug('No known plots specified on command line; plot all known.')
    logger.info('Desired plots set is: %s', desired_plots)
    logger.info('Command line contains RC graphs: %s', not RCGraphs.isdisjoint(desired_plots))
    logger.info('Command line contains SS graphs: %s', not SSGraphs.isdisjoint(desired_plots))

    desired_plots = desired_plots.intersection(gdks)
    if len(desired_plots) == 0:
        logger.debug('No desired plots are defined in the graph defs file.')
        exit(4)
    logger.debug('Desired plots set after checking the graph defs file is: %s', desired_plots)
    for k in gdks:
        logger.debug('Checking if desired plot "%s" is defined.' % k)
        if k not in desired_plots:
            del GraphDefs[k]    # delete graph defs for undesired plots
            continue
        gd = GraphDefs[k]
        DBHosts.add(gd["DBHost"])
        numYAxes = len(gd['Yaxes'])
        for a in gd['Yaxes']:
            a['vars'] = []
        for itm in gd['items']:
            if int(itm['axisNum']) >= numYAxes:
                logger.error('In GraphDefs["%s"], item "%s" references an unknown Y axis.' % (k, itm["dataname"]))
                exit(2)
            gd['Yaxes'][itm['axisNum']]['vars'].extend(itm['variableNames'])
        mpl = 0
        for a in gd['Yaxes']:
            mpl = max(mpl, len(a['vars']))
        gd['max_palette_len'] = mpl
        pass
    if len(GraphDefs) == 0:
        logger.warning('None of the desired plots are in the graph definitions file.')
        exit(3)
    gdks = sorted(GraphDefs.keys())
    logger.debug('Sorted list of graphs (from GraphDefs.keys): %s' % gdks)

    logger.debug('GraphDefs dict is: %s' % json.dumps(GraphDefs, indent=2))
    if LocalDataOnly:
        ServerTimeFromUTC = datetime.utcnow() - datetime.now()      # Use current system as database host for time purposes.
        for h in DBHosts:       # create "dummy" host entry
            logger.debug('Creating "dummy" host entry for %s' % h)
            DBHostDict[h] = dict()
            dbhd = DBHostDict[h]
            dbhd['DBEngine'] = None
            dbhd['haschema'] = 'haschema'
            dbhd['myschema'] = 'myschema'
            dbhd['conn'] = None
            dbhd['twoWeeksAgo'] = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            dbhd['BeginTime'] = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            dbhd['ServerTimeFromUTC'] = ServerTimeFromUTC
            logger.debug("%s Server time offset from UTC: %s" % (h, dbhd['ServerTimeFromUTC']))
            logger.debug("%s BeginTime: %s" % (h, dbhd['BeginTime']))
            logger.debug("%s twoWeeksAgo: %s" % (h, dbhd['twoWeeksAgo']))
        # Datetime objects are not JSON serializable; don't dump host dict.
        # logger.debug('Dummy DBHostDict is: %s' % json.dumps(DBHostDict, indent=2))
        for k in gdks:
            logger.info('             ##############   Preparing graph "%s"   #################' % k)
            ShowGraph(GraphDefs[k])
        logger.info('             ##############   All Done   #################')
        return

    for h in DBHosts:
        DBHostDict[h] = dict()
        dbhd = DBHostDict[h]
        user = cfg['database_reader_user']
        pwd  = cfg['database_reader_password']
        host = cfg['%s_database_host'%h]
        port = cfg['%s_database_port'%h]
        dbhd['haschema'] = cfg['%s_ha_schema'%h]
        dbhd['myschema'] = cfg['%s_my_schema'%h]
        logger.info("%s user %s"%(h, user))
        logger.info("%s pwd %s"%(h, pwd))
        logger.info("%s host %s"%(h, host))
        logger.info("%s port %s"%(h, port))
        logger.info("%s haschema %s"%(h, dbhd['haschema']))
        logger.info("%s myschema %s"%(h, dbhd['myschema']))

        connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=dbhd['haschema'])
        logger.debug("%s database connection string: %s" % (h, connstr))
        Eng = create_engine(connstr, echo = True if Verbosity>=2 else False, logging_name = logger.name)
        dbhd['DBEngine'] = Eng
        logger.debug(Eng)
        with Eng.connect() as conn, conn.begin():
            dbhd['conn'] = conn
            result = conn.execute("select timestampdiff(hour, utc_timestamp(), now());")
            for row in result:
                ServerTimeFromUTC = timedelta(hours=row[0])
            dbhd['twoWeeksAgo'] = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            dbhd['BeginTime'] = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            dbhd['ServerTimeFromUTC'] = ServerTimeFromUTC
            logger.debug("%s Server time offset from UTC: %s" % (h, dbhd['ServerTimeFromUTC']))
            logger.debug("%s BeginTime: %s" % (h, dbhd['BeginTime']))
            logger.debug("%s twoWeeksAgo: %s" % (h, dbhd['twoWeeksAgo']))
            for k in gdks:
                gd = GraphDefs[k]
                if gd["DBHost"] == h:
                    logger.info('             ##############   Preparing graph "%s"   #################' % k)
                    ShowGraph(GraphDefs[k])
        # "DBEngine" and "conn" items in DBHostDict are not serializable, so can't dump them
    # logger.debug('DBHostDict is: %s' % json.dumps(DBHostDict, indent=2))
    logger.info('             ##############   All Done   #################')

if __name__ == "__main__":
    main()
    pass
