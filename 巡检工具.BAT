@echo off
Setlocal enabledelayedexpansion

rem 判断是否以管理员身份运行脚本
set c=%username%
if /i not "%c%" == "administrator" msg * 请在administrator下运行！&& exit

rem 日志表头
echo ======================================== 巡检报告(%date%) ==============================================
echo 巡检开始时间：%time:~0,5%

rem 创建计时程序头
Set _time_start=%time%
Set /a hour_start=%_time_start:~0,2%
Set /a minute_start=1%_time_start:~3,2%-100
Set /a second_start=1%_time_start:~6,2%-100


:: 数据采集与分析
rem 服务器ip
for /f "tokens=4" %%a in ('route print^|findstr 0.0.0.0.*0.0.0.0') do (
echo %%a > 1.txt
for /f %%b in ('type 1.txt ^| findstr 192') do echo IP:%%b
)
del /f /q 1.txt


rem 判断iis和sql是否分离安装
if exist "%Windir%\System32\inetsrv\w3wp.exe" (if exist "%ProgramFiles%\Microsoft SQL Server" echo 此服务器同时安装【IIS】和【SQL】，影响性能，建议分离安装！)

rem 网络延时
for /f "tokens=3 delims=，" %%i in ('ping 10.5.108.254 -n 1 ^|find /v "字节"^|find /v "的"') do ( 
echo %%i>>$ 
) 
for /f "tokens=2 delims=(%%" %%a in ('type $^|find "丢失"') do (set str=%%a) 
for /f "tokens=2 delims==m " %%b in ('type $^|find "平均"') do (set avu=%%b) 
del $ /f /q 
echo 丢包率:%str%%% 平均延时:%avu%ms 

rem 进程数量采集
tasklist >tl.txt
for /f "tokens=2 delims=- " %%i in ('find ".exe" "tl.txt" /i /c') do (echo 当前所有进程的数量:%%i)
del "tl.txt" /q /f /a

rem OS信息采集
for /f "tokens=2 delims==" %%a in ('wmic os get Caption /value') do (
 set OS=%%a
)
echo %OS%

rem CPU核心数量采集
for /f "tokens=3" %%a in ('systeminfo ^| findstr "处理器"') do (
 set CPU=%%a
)
echo %CPU%核

rem 系统位数采集
for /f "tokens=2" %%a in ('systeminfo ^| findstr "系统类型"') do (
 set architecture=%%a
)
echo %architecture%

rem 物理内存大小
for /f "tokens=2" %%a in ('systeminfo ^| findstr "物理内存总量"') do (
 set mem=%%a
)
set mem=%mem:,=%
set /a _mem=%mem%/1000
echo 物理内存 %_mem% G

rem 虚拟内存大小
for /f "tokens=3" %%a in ('systeminfo ^| findstr "最大值"') do (
 set vmem=%%a
)
set vmem=%vmem:,=%
set /a _vmem=%vmem%/1000
echo 虚拟内存 %_vmem% G

rem 如果虚拟内存低于物理内存
if %_vmem% LSS %_mem% (
wmic PageFileSet create name="C:\\pagefile.sys",InitialSize="8000",MaximumSize="8000"
) else (
echo 虚拟内存不低于物理内存，正常
)

rem 是否禁ping
netsh advfirewall firewall show rule name="文件和打印机共享(回显请求 - ICMPv4-In)" profile=domain |findstr 已启用 | findstr 否> null || echo ping正常

netsh advfirewall firewall show rule name="文件和打印机共享(回显请求 - ICMPv4-In)" profile=domain |findstr 已启用 | findstr 否>null && netsh advfirewall firewall set rule name="文件和打印机共享(回显请求 - ICMPv4-In)" new enable=yes >null&&echo 发现服务器禁ping，不便于管理，已自动启用ping

rem 系统安装时间
for /f "tokens=2" %%a in ('systeminfo ^| findstr "初始安装日期"') do (
 set installtime=%%a
)
echo %installtime:~0,10%

rem 关机记录
PATH D:\Program Files (x86)\1.8.5897.27296\Functions\;%PATH%
call Uptime d h n s
echo 系统连续运行：%d% 天，%h% 小时，%n% 分，%s% 秒。

for /f "tokens=2,3" %%a in ('systeminfo ^| findstr 系统启动时间') do (
echo 上次关机时间: %%a %%b
)

rem 是否掉域
for /f "tokens=2" %%a in ('systeminfo ^| findstr "域"') do (
 set domain=%%a
)
echo %domain%

rem 主机名是否符合规范
echo %computername% > computername.txt
findstr /i "WH-" computername.txt > null && echo 计算机名符合规定 || echo 此计算机名不符合规范
del computername.txt

rem mstsc远程服务是否开启
netstat -ano |findstr 3389 > null && echo 远程服务正常开启||(echo Windows Registry Editor Version 5.00>3389.reg
echo [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server]>>3389.reg
echo "fDenyTSConnections"=dword:00000000>>3389.reg
echo [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\Wds\rdpwd\Tds\tcp]>>3389.reg
echo "PortNumber"=dword:00000d3d>>3389.reg
echo [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp]>>3389.reg
echo "PortNumber"=dword:00000d3d>>3389.reg
regedit /s 3389.reg
del 3389.reg)&& echo 远程服务未开启，已将其启动

rem DNS是否被篡改
for /f "tokens=2 delims=:" %%a in ('netsh interface ipv4 show dnsservers "以太网" ^| findstr DNS') do (
set b=%%a
set c=!b:~12,16!
if "!c!" neq "10.5.11.5" (
netsh interface ip set dns "以太网" source=static addr=10.5.11.5
netsh interface ip add dns "以太网" addr=10.5.11.6
)else (echo DNS正常)
)

rem iis站点统计
cd C:\Windows\System32\inetsrv
for /f "tokens=4 delims=:"  %%a in ('appcmd.exe list sites' ) do (
set /a n+=1
echo %%a
)
echo 共有%n%个iis站点
for /f "tokens=4 delims=:"  %%a in ('appcmd.exe list sites ^| findstr /i started' ) do (
set /a m+=1
echo %%a
)
echo 其中%m%个运行中
echo 它们的端口分别是：
for /f "tokens=4 delims=:"  %%a in ('appcmd.exe list sites ^| findstr /i started' ) do (
echo %%a
)

endlocal

setlocal 

rem 硬盘空间统计
for /f "delims=g" %%a in ('cmd /u /cEcho,有') do set "Tab=%%a"
set w=wmic diskdrive where "MediaType like 'fixed%%'"
set "w=%w% get DeviceID^,Model^,Size"
for /f "tokens=1*delims==" %%i in ('%w% /value ^| find "="') do (
    if /i "%%i" == "DeviceID" set /a n+=1
    set "%%i!n!=%%j"
)
set "w1=wmic path Win32_DiskDriveToDiskPartition get Antecedent^,Dependent"
set "w2=wmic path Win32_LogicalDiskToPartition get Antecedent^,Dependent"
for /l %%i in (1 1 !n!) do (
    call :GetSize !Size%%i!000 size
    if !size! gtr 102400 (set /a size/=1024 & set "G=GB") else set "G=MB"
    set /p=硬盘%%i:%Tab%<nul
    set /p=大小:!size:~,-2!.!size:~-2!!G!%Tab%<nul
    echo,
    for /f tokens^=4delims^=^" %%a in ('%w1% ^| find /i """!DeviceID%%i!"""') do (
        for /f tokens^=4delims^=^" %%b in ('%w2%^|find /i """%%a"""') do (
            set "w3=wmic logicaldisk where "Name='%%b'" get FreeSpace^,Size"
            for /f "tokens=1,2" %%c in ('!w3!^|findstr [0-9]') do (
                call :GetSize %%c000 free
                call :GetSize %%d000 size
                set /a used=size-free
                if !size! gtr 102400 (
                    set /a size/=1024,used/=1024 & set "G=GB"
                ) else set "G=MB"
                set /a used=1000*used/size
                if "!used:~,-1!" == "" set "used=0!used!"
                set /p=分区%%b%Tab%<nul
                set /p=大小:!size:~,-2!.!size:~-2!!G!%Tab%<nul
                if !free! gtr 102400 (
                    set /a free/=1024 & set "G=GB"
                ) else set "G=MB"
                set /p=剩余:!free:~,-2!.!free:~-2!!G!%Tab%<nul
                set /p=使用率:!used:~,-1!.!used:~-1!%%<nul
                echo,
            )
        )
    )
    echo,
)>> D:\mem.txt

%--------------------------------------------------------------------------------------------------------------------%

:: 配置管理

%--------------------------------------------------------------------------------------------------------------------%

:: 数据迁移备份

%--------------------------------------------------------------------------------------------------------------------%

:: 故障巡检
IF NOT EXIST "C:\Program Files\Unlocker\Unlocker.exe" (
start /wait \\10.5.11.15\资料交换区\服务器巡检\unlocker.exe /silent && xcopy C:\"Program Files"\unlocker\unlocker.exe %windir% /y)
rem 删除sql错误日志
unlocker C:\"Program Files"\"Microsoft SQL Server"\*errorlog* -S -D
unlocker C:\"Program Files"\"Microsoft SQL Server"\*.mdmp -S -D
rem 删除iis日志
unlocker C:\Windows\Logs\CBS\*.log -S -D
unlocker C:\inetpub\logs\LogFiles -S -D
rem 删除其他垃圾文件
del /f /s /q %systemdrive%\*.tmp 
del /f /s /q %systemdrive%\*._mp 
del /f /s /q %systemdrive%\*.log 
del /f /s /q %systemdrive%\*.gid 
del /f /s /q %systemdrive%\*.chk 
del /f /s /q %systemdrive%\*.old 
del /f /s /q %windir%\*.bak  
del /f /q %windir%\prefetch\*.* 
rd /s /q %windir%\temp & md %windir%\tempemp% &md %temp% 
del /f /q %userprofile%\cookies\*.* 
del /f /q %userprofile%\recent\*.* 
rd /s /q \"%userprofile%\Local Settings\Temporary Internet Files\" 

rem d盘同名压缩包删除
d:
dir *.rar /b >> 1.txt
for /f "tokens=1 delims=." %%a in (1.txt) do (
if exist %%a.bak del %%a.rar&if exist d:\%%a del %%a.rar
del /f /s /q 1.txt 
)

rem 清理tempdb
for /f "tokens=1" %%a in ('wmic service get name ^| findstr  "MSSQL$SQL MSSQLSERVER"') do (
net stop %%a > NULL & net start %%a > NULL)
) 
echo TempDB清理完毕

rem  统计老数据库文件
forfiles /p d:\ 2>null  /s /m *.txt  /d -365 /c "cmd /c echo @path @fsize 2>null 1>> e:\1.txt"
for /f  %%a in (e:\1.txt) do (
set /a n+=1
)
echo 共有%n%个1年前的老数据库，请及时清理
del /f /s /q e:\1.txt

rem 清空回收站
for %%drive_id in (C D E F G H I J K L M N O P Q R S T U V W X Y Z)do (
	if exist %%drive_id: (
		del /f /s /q /a  %%drive_id:\$Recycle.Bin
	)
)
%--------------------------------------------------------------------------------------------------------------------%

:: 性能调优
rem 注销无效远程连接
for /f "skip=1 tokens=1,2" %%b in ('query user') do ( 
if /i not "%%b" EQU ">administrator" (logoff %%c && echo 已经注销用户%%b >>1.txt)
)

rem 内存释放
IF NOT EXIST "%windir%\empty.exe" xcopy \\10.5.11.15\empty.exe %windir% /y 
empty *

rem 静默卸载参数
if exist C:\"Program Files (x86)"\"Elaborate Bytes" (
C:\Program Files (x86)\Elaborate Bytes\VirtualCloneDrive\vcd-uninst.exe /y
del /f /q C:\ProgramData\Microsoft\Windows\"Start Menu"\Programs\"Elaborate Bytes"\VirtualCloneDrive\"Virtual CloneDrive.lnk"
unlocker ?C:\"Program Files (x86)"\"Elaborate Bytes" -S -D
echo VirtualCloneDrive卸载完成
)

rem 关闭无用服务
%关闭正在运行的不合规定服务%
for /f "tokens=4 delims= " %%a in ('sc query gupdate ^| findstr /i state') do (
if "%%a" == "RUNNING" sc stop gupdate&&sc config gupdate start= DISABLED&&echo 禁用谷歌升级服务gupdate
%if NOT "%%a" == "RUNNING" echo xxx%
)
for /f "tokens=4 delims= " %%a in ('sc query gupdatem ^| findstr /i state') do (
if "%%a" == "RUNNING" sc stop gupdatem&&sc config gupdatem start= DISABLED&&echo 禁用谷歌升级服务gupdatem
%if NOT "%%a" == "RUNNING" echo xxx%
)

%--------------------------------------------------------------------------------------------------------------------%

:: 应用监控
rem iis进程守护
if exist "%Windir%\System32\inetsrv\inetinfo.exe" tasklist /svc | findstr /i "IISAdmin">null&&echo [%time:~,-3%]IIS工作正常||(sc start iisadmin > null && echo [%time:~,-3%]发现IIS服务中断，巡检工具已将其恢复)

if exist "%Windir%\System32\inetsrv\inetinfo.exe" tasklist /svc | findstr /i "w3svc">null&&echo [%time:~,-3%]w3svc工作正常||(sc start w3svc > null && echo [%time:~,-3%]发现w3svc服务中断，巡检工具已将其恢复)

rem asp.net进程守护
if exist "%Windir%\System32\inetsrv\inetinfo.exe" (
for /f "tokens=1" %%a in ('wmic service get name ^| findstr  "aspnet_state"') do (
(tasklist /SVC | findstr %%a > null && echo [ %time:~,-3% ] %%a工作正常)|| (net start %%a >null && echo [ %time:~,-3% ]巡检发现%%a服务中断，工具已将其恢复)
)
)
rem sql进程守护
if exist "%ProgramFiles%\Microsoft SQL Server"(
for /f "tokens=1" %%a in ('wmic service get name ^| findstr  "MSSQL$SQL MSSQLSERVER"') do (
(tasklist /SVC | findstr %%a > null && echo [ %time:~,-3% ] %%a工作正常)|| (net start %%a >null && echo [ %time:~,-3% ]巡检发现%%a服务中断，工具已将其恢复)
)
)

%--------------------------------------------------------------------------------------------------------------------%
::计算巡检所用时间
Set _time_end=%time%
Set /a hour_end=%_time_end:~0,2%
Set /a minute_end=1%_time_end:~3,2%-100
Set /a second_end=1%_time_end:~6,2%-100

if %second_end% lss %second_start% (
    Set /a second_end=%second_end%+60
    Set /a minute_end=%minute_end%-1
)
Set /a second=%second_end%-%second_start%
:: 计算分钟数
if %minute_end% lss %minute_start% (
    Set /a minute_end=%minute_end%+60
    Set /a hour_end=%hour_end%-1
)
Set /a minute=%minute_end%-%minute_start%
:: 计算小时数
if %hour_end% lss %hour_start% (
    Set /a hour_end=%hour_end%+24
)
Set /a hour=%hour_end%-%hour_start%
rem 计时程序结束
echo 本次巡检用时:%hour%时%minute%分%second%秒

pause
%--------------------------------------------------------------------------------------------------------------------%

:GetSize
set "num=%1" & set "n=" & set "%2="
for %%a in (16 8 4 2 1) do (
    if not "!num:~%%a!"=="" set /a n+=%%a & set "num=!num:~%%a!"
)
set "num=%1" & set /a n-=6
for /l %%a in (!n! -1 1) do (
    set "s=!num:~,-%%a!"
    if "!s:~,1!" == "0" set "s=!s:~1!"
    set /a m=s%%1048576,s/=1048576
    set "%2=!%2!!s!"
    set "num=!m!!num:~-%%a!"
)
if not defined %2 (
    set "%2=!num:~,-1!"
) else if "!%2:~,1!" == "0" set "%2=!%2:~1!"