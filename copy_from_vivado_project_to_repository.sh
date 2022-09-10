#! /bin/bash

echo "Copying files from the Vivado project directory into the repository directory ..."

PROJECTDIR="$HOME/Desktop/Vivado2022/TRexJuniorNanologgerPlus/TRexJuniorNanologgerPlus.srcs"

cp ${PROJECTDIR}/sources_1/new/*.vhdl ${PWD}
cp ${PROJECTDIR}/constrs_1/new/*.xdc  ${PWD}
