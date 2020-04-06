#!/bin/bash

# Helfer script um remote die Uhrzeit einzustellen.

sudo timedatectl set-time "$1" && echo "Zeit erfolgreich gesetzt"