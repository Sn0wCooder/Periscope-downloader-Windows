@echo off

setlocal EnableDelayedExpansion

title Periscope video downloader v1.2

echo +-----------------------------------------------+
echo ^|        Periscope video downloader v1.2        ^|
echo +-----------------------------------------------+
echo ^|         This script helps you download        ^|
echo ^|     periscope.tv and watchonperiscope.com     ^|
echo ^|    videos (replays) in original .ts format.   ^|
echo +-----------------------------------------------+
echo ^|       Made by @nikisdro  [ 2015-07-22 ]       ^|
echo +-----------------------------------------------+
echo.
echo Paste full replay URL below (right click - Paste) and press Enter
echo.
echo Example 1: https://www.periscope.tv/w/aHjwKTQxNTEyMTN8NDE2MDg5NTEz0lYQkT__nA74BMLHSxX8fsD_ZgyA1aiUgi1M1HLMxg==
echo.
echo Example 2: https://watchonperiscope.com/broadcast/43512402
echo.
set /p url="URL: "

set url_="%url%"

if [%url_%]==[""] goto end

cd bin

if not %url_:watchon=% == %url_% (
	goto watchon
) else (
	goto normal
)

::::::: Watch On Periscope pre-parser  :::::::

:watchon

set broadcast_id=%url:*/broadcast/=%

aria2c --allow-overwrite=true --connect-timeout=5 --retry-wait=5 -t 5 -m 0 -s 1 -j 4 https://watchonperiscope.com/api/accessChannel?broadcast_id=%broadcast_id% -o ../txt/json0.txt

xidel ../txt/json0.txt -e "($json).share_url">../txt/vars0.txt

set /p url=<../txt/vars0.txt

:normal

set token=%url:*/w/=%

::::::: Constructing file name  :::::::

aria2c --allow-overwrite=true --connect-timeout=5 --retry-wait=5 -t 5 -m 0 -s 1 -j 4 https://api.periscope.tv/api/v2/getBroadcastPublic?token=%token% -o ../txt/json1.txt

xidel ../txt/json1.txt -e "($json).user.username,($json).broadcast.start">../txt/vars1.txt

(
set /p username=
set /p datetime=
)<../txt/vars1.txt

set date=%datetime:~0,10%
set hours=%datetime:~11,2%
set mins=%datetime:~14,2%

set filename=%username%_%date%_%hours%-%mins%.ts

::::::: Setting up cookies ::::::: 

aria2c --allow-overwrite=true --connect-timeout=5 --retry-wait=5 -t 5 -m 0 -s 1 -j 4 https://api.periscope.tv/api/v2/getAccessPublic?token=%token% -o ../txt/json2.txt

xidel -q ../txt/json2.txt -e '($json).replay_url,($json).cookies()/(Name,Value)'>../txt/vars2.txt

(
set /p replay_url=
set /p name1=
set /p value1=
set /p name2=
set /p value2=
set /p name3=
set /p value3=
)<../txt/vars2.txt

set header=Cookie:%name1%=%value1%;%name2%=%value2%;%name3%=%value3%

::::::: Downloading playlist and all chunks :::::::

aria2c --allow-overwrite=true --header %header% --connect-timeout=5 --retry-wait=5 -t 5 -m 0 -s 1 -j 4 %replay_url% -o ../txt/playlist.txt

set base_url=%replay_url:/playlist.m3u8=%

cd ../txt

findstr "chunk" playlist.txt>chunklist.txt
type NUL > downloadlist.txt
for /f %%i in (chunklist.txt) do echo %base_url%/%%i>>downloadlist.txt

cd ../bin

aria2c --uri-selector=inorder --allow-overwrite=true --header %header% --connect-timeout=5 --retry-wait=5 -t 5 -m 0 -s 1 -j 4  -d ../ts -i ../txt/downloadlist.txt

::::::: Merging all chunks into one file :::::::

cd ../ts

for %%f in (*.ts) do (
    for /f "tokens=2 delims=_." %%n in ("%%f") do (
       set /a "newname=%%n+100000"
       ren %%f !newname!.ts
	)
)

copy /b "*.ts" "../%filename%"

::::::: Deleting temp files :::::::

cd ..

rd /s /q ts txt

echo.
echo +-----------------------------------------------------------+
echo ^| Done^^! You file is saved as %filename%
echo +-----------------------------------------------------------+
echo.

:end
pause