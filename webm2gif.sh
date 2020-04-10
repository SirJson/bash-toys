#!/bin/bash

if [[ "$1" == "--with-palette" ]]; then
    shift
    echo "generate palette"
    ffmpeg -y -i "$1" -vf palettegen "$1-palette.png"
    echo "render $2"
    ffmpeg -y -i "$1" -i "$1-palette.png" -filter_complex paletteuse -r 10 "$2"
else
    echo "simple render $2"
    ffmpeg -i "$1" -pix_fmt rgb24 "$2"
fi