"""Rebuild the test-only fonts with fonttools==4.60.1; see README.md."""
import csv
import sys
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
text = (ROOT / 'tests/dialogue_pagination_test.gd').read_text()
with (ROOT / 'addons/rpgeventstudio/i18n/ui.csv').open() as stream:
    for row in csv.reader(stream):
        if row and row[0] in ('game.advance_more', 'game.advance_hint', 'game.choice_hint'):
            text += ''.join(row)
codepoints = sorted(set(map(ord, text)) | set(range(32, 127)))
for source, name in zip(sys.argv[1:], ('sans', 'serif')):
    font = TTFont(source)
    options = subset.Options()
    options.name_IDs = ['*']
    sub = subset.Subsetter(options=options)
    sub.populate(unicodes=codepoints)
    sub.subset(font)
    family = 'RPGE Test ' + name.title()
    for record in font['name'].names:
        if record.nameID in (1, 4, 16):
            record.string = family.encode(record.getEncoding())
        elif record.nameID == 6:
            record.string = family.replace(' ', '').encode(record.getEncoding())
    cff = font['CFF '].cff
    cff.fontNames = [family.replace(' ', '')]
    cff.topDictIndex[0].FamilyName = family
    cff.topDictIndex[0].FullName = family
    font.save(HERE / ('pagination_' + name + '.otf'))
