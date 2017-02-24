#! /bin/bash

platform=$(dpkg-architecture -l | head -n 1 | tr '=' '\n' | tail -n 1)

echo 'Building vertigo-bin'
echo

set -x

mkdir compile

rm compile/*
cp vertigo/src/* compile/.

cd compile

gcc -c m_resolve_address.c -o m_resolve_address.o

fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE install
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE install_make 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE maketheme 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE vbbsutil 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mide 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mis 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mplc 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mtype 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mutil 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE vertigo 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE fidopoll 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE vertpack 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE nodespy 
fpc -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE qwkpoll

mkdir ../bin
mkdir ../bin/release

cp install ../bin/
cp install_make ../bin/
cp maketheme ../bin/release/
cp vbbsutil ../bin/release/
cp mide ../bin/release/
cp mis ../bin/release/
cp mplc ../bin/release/
cp mtype ../bin/release/
cp mutil ../bin/release/
cp vertigo ../bin/release/
cp fidopoll ../bin/release/
cp vertpack ../bin/release/
cp nodespy ../bin/release/
cp qwkpoll ../bin/release/
cp -R ../vertigo/etc/* ../bin/release/
cd ..
cd bin

./install_make install_data release/\* ROOT
./install_make install_data release/data/\* DATA
./install_make install_data release/text/\* TEXT
./install_make install_data release/menus/\* MENUS
./install_make install_data release/scripts/\* SCRIPT
./install_make install_data release/doc/\* DOCS

rm -rf compile
