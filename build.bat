@echo off
echo 'Building vertigo-bin'
md compile

del compile\*.*

copy vertigo\src\*.* compile

cd compile


gcc.exe -c m_resolve_address.c -o m_resolve_address.o


fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE install
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE install_make 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE maketheme 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE vbbsutil 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mide 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mis 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mplc 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mtype 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE mutil 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE vertigo 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE fidopoll 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE vertpack 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE nodespy 
fpc -Fu"C:\Program Files (x86)\CodeBlocks\MinGW\lib" -CX -XX -Xs -O3 -B -OoREGVAR -OoSTACKFRAME -OoPEEPHOLE -OoASMCSE qwkpoll

md ..\bin
md ..\bin\release

copy install.exe ..\bin\
copy install_make.exe ..\bin\
copy maketheme.exe ..\bin\release\
copy vbbsutil.exe ..\bin\release\
copy mide.exe ..\bin\release\
copy mis.exe ..\bin\release\
copy mplc.exe ..\bin\release\
copy mtype.exe ..\bin\release\
copy mutil.exe ..\bin\release\
copy vertigo.exe ..\bin\release\
copy fidopoll.exe ..\bin\release\
copy vertpack.exe ..\bin\release\
copy nodespy.exe ..\bin\release\
copy qwkpoll.exe ..\bin\release\

md ..\bin\release\data
md ..\bin\release\text
md ..\bin\release\menus
md ..\bin\release\scripts
md ..\bin\release\doc

copy ..\vertigo\etc\*.* ..\bin\release\
copy ..\vertigo\etc\data\*.* ..\bin\release\data\
copy ..\vertigo\etc\text\*.* ..\bin\release\text\
copy ..\vertigo\etc\menus\*.* ..\bin\release\menus\
copy ..\vertigo\etc\scripts\*.* ..\bin\release\scripts\
copy ..\vertigo\etc\doc\*.* ..\bin\release\doc\

cd ..
cd bin

install_make install_data release\*.* ROOT
install_make install_data release\data\*.* DATA
install_make install_data release\text\*.* TEXT
install_make install_data release\menus\*.* MENUS
install_make install_data release\scripts\*.* SCRIPT
install_make install_data release\doc\*.* DOCS

cd ..

