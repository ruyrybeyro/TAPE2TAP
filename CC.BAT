@echo off
rem Batch file for Turbo Assembler
tasm /zi/ml tape2tap
tlink /v /l tape2tap
echo.
echo For the final executable, don't forget to strip the debug info
