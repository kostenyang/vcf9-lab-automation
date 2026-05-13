@echo off
dir E:\*.ova /b > "%~dp0e-drive-ovas.txt" 2>&1
dir E:\*.ovf /b >> "%~dp0e-drive-ovas.txt" 2>&1
echo --- all files on E:\ --- >> "%~dp0e-drive-ovas.txt"
dir E:\ /b >> "%~dp0e-drive-ovas.txt" 2>&1
type "%~dp0e-drive-ovas.txt"
pause
