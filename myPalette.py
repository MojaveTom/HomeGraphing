'''
Utility class for bokeh palettes.
If colorName is a name of a color name, a palette of just one color is created.
If colorName is a name of a color palette, a palette of the desired length is created.

Defines function to return the next color from the palette, recycling the palette as required.
    The next color can be initialized with an integer index into the palette
'''

# This function extracted to a separate file since VSCode can't seem to properly import bokeh.palettes
import logging

from bokeh.palettes import all_palettes, linear_palette
import bokeh.colors as bc
import itertools as it

logger = logging.getLogger(__name__)

class Palette(object):

    # _Palette = all_palettes['Dark2'][8]
    # callGroups = {}

    def __init__(self, colorName, num=None, *args, **kwargs):

        if kwargs.get('loggingLevel') is not None:
            logger.setLevel(kwargs.get('loggingLevel'))

        logger.debug('Creating palette for colorName: %s with %s colors.' % (colorName, num))
        paletteFamilies = all_palettes.keys()
        self.callGroups = {}
        try:
            # See if the colorName
            self._Palette = [eval("bc.named."+colorName+".to_hex()")]
            logger.debug('Creating one color palette: %s' % self._Palette)
            return
        except:
            if colorName not in paletteFamilies:
                logger.warning('"%s" is neither a known color name nor a known color palette name; using Dark2[8].' % colorName)
                return
            pass
        _num = num
        if _num is None or _num < 1: _num = 8
        pf = all_palettes[colorName]
        # if _num > max(pf.keys()):
        #     logger.debug('The number of lines in the graph exceeds the number of colors in the palette.  Switch to a larger palette.')
        #     pf = all_palettes['Viridis']
        pfk = pf.keys()
        if _num in pfk:
            self._Palette = pf[_num]
            logger.debug('Creating predefined palette: %s' % self._Palette)
            return
        maxp = max(pfk)
        rptcnt = ((_num-1) // maxp) + 1
        if _num > maxp:
            minContainPalette = maxp
        else:
            minContainPalette = min(list(it.filterfalse(lambda x: x<_num, pfk)))
        if rptcnt == 1:
            logger.debug('Generating pallette of %s colors from %s of %s.' % (_num, minContainPalette, pf[minContainPalette]))
            self._Palette = pf[minContainPalette][0:_num]                   # Take first _num colors from palette.
            # self._Palette = linear_palette(pf[minContainPalette], _num)   # Take evenly spaced colors form palette.
        else:
            self._Palette = linear_palette(pf[maxp]*rptcnt, _num)
        logger.debug('Creating palette: %s' % self._Palette)

    def nextColor(self, group, index=None):
        try:
            ind = int(index) if index is not None else 0
        except Exception as e:
            logger.exception('nextColor index argument must be convertible to integer.\n%s', e)
            return None
        if len(self._Palette) == 0:
            logger.debug('Attempting to get a color from an empty palette.')
            return None
        ind = ind % len(self._Palette)
        logger.debug('Requesting color at index %s.', ind)
        if group not in self.callGroups.keys():
            logger.debug('Creating new "nextColor" call group named "%s"', group)
            self.callGroups[group] = ind
        if index is not None:
            self.callGroups[group] = ind
        ind = self.callGroups[group]
        logger.debug('Retrieving color at index %s (goup is "%s").' % (ind, group))
        self.callGroups[group] = (ind + 1) % len(self._Palette)
        logger.debug('Next color index for group "%s" is %s; color is: %s.' % (group, ind, self._Palette[ind]))
        return self._Palette[ind]
