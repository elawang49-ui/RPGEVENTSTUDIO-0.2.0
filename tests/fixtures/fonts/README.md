# Portable pagination fixtures

These renamed, test-only subsets come from Noto Sans CJK SC Regular and Noto
Serif CJK SC Regular at upstream commit
`f8d157532fbfaeda587e826d4cd5b21a49186f7c`:

- https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf
- https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf

Copyright notices are preserved in each font's name table. Noto Sans: © 2014-2021
Adobe; Noto Serif: see its embedded copyright notice. Each font remains under the
SIL Open Font License 1.1; full upstream licenses are OFL-Sans.txt and
OFL-Serif.txt. The RPGEVENTSTUDIO custom license does not replace them.

The subset includes characters used in the pagination suite, the advance/choice
hints and ASCII. Family names are changed to RPGE Test Sans / RPGE Test Serif.
These files are not shipped in the standalone plugin ZIP and do not change the
host game's font selection. Runtime system-font behavior is covered separately
by dialogue_layout_test.gd and other UI suites.

To rebuild, install `fonttools==4.60.1` into a disposable Python virtualenv,
download the two files above, then run from the repository root:

```sh
python tests/fixtures/fonts/build_subset.py /path/to/NotoSansCJKsc-Regular.otf /path/to/NotoSerifCJKsc-Regular.otf
```

Input SHA-256:

- Sans: `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`
- Serif: `2a2eae2628df83556c54018c41e20fa532c1b862c5256ae8b3f23feb918d12ca`

No system font, network access or fonttools installation is needed to run tests.
