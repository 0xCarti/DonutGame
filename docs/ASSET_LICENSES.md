# Asset provenance

## Original project assets

The donut machine, donuts, counter, trays, signage, background props, materials,
and animations are original procedural geometry and animation authored for this
project. No commercial game models or textures are included. Equipment names in
the design discussion are references; the prototype uses an original fictional
machine design.

All WAV files in `assets/audio/` were synthesized specifically for this project
with `tools/generate_audio.py`. The thirteen effects and the original 30-second
fairground waltz use mathematical oscillators and deterministic generated noise.
They contain no sampled recordings, downloaded sound effects, or third-party
music. The generator is included so the assets can be reproduced and modified.

## Godot Engine

Godot Engine is distributed under the MIT license. Engine copyright and third-party
notices remain with their respective holders. See the official [Godot license](https://godotengine.org/license/)
and [third-party notices](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt).
The source project's license does not replace Godot's license or those notices.

Version used during development: **4.7.2 stable**. Official release downloads:
[Godot 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
The complete MIT license and third-party notices from that exact source tag are
vendored as `docs/licenses/Godot-LICENSE.txt` and
`docs/licenses/Godot-COPYRIGHT.txt`. Source URLs and checked hashes are recorded
in `docs/licenses/SOURCES.json`. The build script includes both in distributions.

## Fredoka typeface

`assets/fonts/Fredoka.ttf` is the unmodified Fredoka variable font obtained from
the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/fredoka)
([original font download](https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf)).
Its filename was shortened locally; the font contents were not modified.

`assets/fonts/Fredoka-Medium.ttf`, used by the game, is a fixed instance generated
with fontTools from that variable source, with **wght=550** and **wdth=100**.
This generated instance is also distributed under SIL OFL 1.1. The reproducible
fontTools command is documented in `docs/BUILDING.md`.

Copyright 2016 The Fredoka Project Authors
([Fredoka project](https://github.com/hafontia/Fredoka-One)).
Licensed under the **SIL Open Font License, Version 1.1**. The complete copyright
notice and license are retained in `assets/fonts/OFL.txt` and must accompany
redistributed copies of the font.
