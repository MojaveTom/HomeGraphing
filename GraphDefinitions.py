'''
Define the schema for graph definition dictionary.
'''

import os
import json
import logging
from schema import Schema, And, Or, Use, Optional, SchemaError
# import matplotlib.cm as cm
import bokeh.palettes as bp
import bokeh.colors as bc

logger = logging.getLogger(__name__)

MyPath = os.path.dirname(os.path.realpath(__file__))
logger.debug('MyPath in GraphDefinitions is: %s' % MyPath)
# logger.debug('bokeh __palettes__ are: %s' % bp.__palettes__)
bokehKnownColors = bc.named.__all__
bokehPaletteFamilies = list(bp.all_palettes.keys())
palettesAndColors = bokehPaletteFamilies + bokehKnownColors

# logger.debug('bokeh palette families are: %s' % bokehPaletteFamilies)

            # And(str, lambda s: s in cm.datad.keys())
#                         # And(str, lambda s: s in cm.datad.keys())
# Or(
gds = {str: {'GraphTitle': str
        , 'DBHost': And(Use(str.lower), Use(str.lower), lambda s: s in ('rc', 'ss'), error='DBHost must be "RC" or "SS"')
        , 'outputFile': str
        , Optional('ShowGraph', default=True): bool
        , Optional('graph_color_map', default='Dark2'): Or(
            And(str, lambda s: s in bokehPaletteFamilies)
            , None, error='Graph color map not defined.')
        , 'XaxisTitle': str
        , 'Yaxes': [{'title': str
                    , Optional('color_map', default=None): Or(
                        And(str, lambda s: s in palettesAndColors)
                        , None, error='Axis color map not defined.')
                    , Optional('color', default=None): Or(
                        And(str, lambda s: s in bokehKnownColors)
                        , None, error='Axis color not defined.')
                    , Optional('location', default='left'): 
                        And(str, lambda s: s in ('left', 'right'), error='Axis location must be "left" or "right".')}]
        , 'items': [ { 'query': Or(str, None)
                , 'variableNames': [str]
                , 'datafile': str
                , 'dataname': str
                , Optional('axisNum', default=0): Use(int)
                , Optional('includeInLegend', default=True): Use(bool)
                , Optional('lineType', default='line'): 
                        And(str, lambda s: s in ('line', 'step'), error='Item lineType must be "line" or "step".')
                , Optional('dataTimeZone', default='serverLocal'): 
                        And(str, lambda s: s in ('serverLocal', 'UTC'), error='Item dataTimeZone must be "serverLocal" or "UTC".')
                , Optional('lineMods', default={"glyph.line_width": "2", "muted_glyph.line_width": "4"}): {str: str}
                , Optional('color_map', default=None): Or(
                    And(str, lambda s: s in bokehPaletteFamilies)
                    , None, error='Axis color map not defined.')
                , Optional('color', default=None): Or(
                    And(str, lambda s: s in bokehKnownColors)
                    , None, error='Axis color not defined.') } ] } }

# Doesn't work since some of the keys are class objects defined in schema.
# Can't pickle gds either.
# with open(os.path.join(MyPath, "GraphDefsSchema.json"), 'w') as file:
#     json.dump(gds, file, indent=2)

def GetGraphDefs(GraphDefFile=None):
    GraphDefsSchema = Schema(gds, name = 'Graphing Schema')
    if GraphDefFile is None:
        GraphDefFile = os.path.join(MyPath, "OneLineGraph.json")
    if not os.path.isfile(GraphDefFile) and not os.path.isabs(GraphDefFile):
        GraphDefFile = os.path.join(MyPath, GraphDefFile)
    logger.debug('The GraphDefFile is: %s' % GraphDefFile)
    if os.path.isfile(GraphDefFile):
        logger.debug('The GraphDefFile "%s" exists' % GraphDefFile)
        with open(GraphDefFile, 'r') as theFile:
            GraphDefs = json.load(theFile)
            logger.debug('The GraphDefFile "%s" loaded sucessfully' % GraphDefFile)
    else:
        logger.critical('The graph definition file "%s" does not exist.' % GraphDefFile)
        exit(1)

    try:
        GraphDefs = GraphDefsSchema.validate(GraphDefs)
        logger.debug('Graph definitions file is valid.')
    except SchemaError as e:
        logger.critical('Graph definition dictionary is not valid.  %s', e)
        logger.debug('%s' % e.autos)
        exit(1)
    return GraphDefs    
