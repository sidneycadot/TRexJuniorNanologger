#! /bin/bash

echo "Copying files from the repository directory into the Vivado project directory ..."

PROJECTDIR="$HOME/Desktop/Vivado2022/TRexJuniorNanologgerPlus/TRexJuniorNanologgerPlus.srcs"

cp ${PWD}/*.vhdl ${PROJECTDIR}/sources_1/new
cp ${PWD}/*.xdc  ${PROJECTDIR}/constrs_1/new
