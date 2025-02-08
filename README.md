# MOS-6502-Badapple
For initializing and uploading data to an OLED using a WS5C22 VIA with I2C. Assembled with dasm.\
Code uploaded to processor using [byoc debugger](https://github.com/SuperTails/byobc-debugger)

This program draws frames from badapple.bin to an OLED. Our computer only has a max memory of ~5kb, which severly limits the number of frames capable of being stored, so I skip every other frame\
to save space and speed up the animation.

This was a final project for a student taught course 98-341 Build Your Own Breadboard Computer in S24, taught by [Carson Swolveland](https://github.com/SuperTails/).\

[![Breadboard Computer Playing BadApple](https://img.youtube.com/vi/tCdFdv-RszU/0.jpg)](https://www.youtube.com/shorts/tCdFdv-RszU)
