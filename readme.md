# Jenkins搭建.NET自动编译测试并实现半增量部署

标签（空格分隔）： 运维 jenkins

---
前言

> 以前写前端项目打包部署，都是手动运行命令，打包完，然后压缩，再上传到服务器解压。 这种方式确实有点low并且效率也不高。
> 自从用了Jenkins持续集成工具，写前端项目越来越工程化，再也不用担心忘记部署项目，也不用烦躁每次打包压缩后还要部署多个服务器和环境，更开心的是每次家里写完代码，不用远程公司部署项目，提交代码后自动会为你部署。
> 本文基于.NET4.0的web项目和SVN的代码仓库以及Windows(其他系统平台大同小异)，简述Jenkins实现自动部署的配置。


#1项目开发与持续优化
##1.1持续部署
有时候开发人员在更新代码时在本地测试是正常的，但放在服务器上运行就会出问题。只有在生产环境下能正常跑起来的代码才算合格，关注点在于项目功能部署至服务器后可以运行。
引用一些名词解释：

> 部署（deployment）还是发布（release）？部署一般指把应用或者服务“安装”到目标环境（开发、测试或者生产）中，而发布则应指把应用或者服务交付给最终用户使用。尽管这两个动作（尤其是在生产环境中）经常是同时发生的，但它们理应是两个完全不同的阶段。实际上一个好的持续交付流程恰恰应该把“部署”和“发布”解耦，变成两个可以独立控制的阶段。
> 部署的内容包括什么？无论是增量部署还是全量部署，都需要关注其部署的内容是什么，尤其是在广泛讨论微服务的今天。如果从部署角度看，我们把任何可以独立部署的内容称为一个“部署单元”。一个部署单元可以是一个模块，几个模块的联合体或者一个完整的应用，而如何划分则要视具体场景来定。一般来说，划分部署单元的最佳实践为一个可以独立演化、部署且和应用其他部分松耦合的集合。

（1）全量部署 full
全部文件重新拷贝并覆盖。优点稳定性好，但对带宽的要求大，更新时间长。
（2）增量部署 min
更新上个版本与最新版本之间的文件。优点速度快，对带宽的要求小，更新时间短，但若更新失败，则需要全量更新覆盖一次。
引用增量部署的优势：

> **部署速度快。**增量部署每次仅对增量部分进行更新，无论是文件分发还是配置更新的内容都会更少，部署需要的时间也就相对较短。
> **减少变化量。**增量部署可以减少对于整个系统的变化幅度，很多已经完成的配置工作不需要每次重复设置。从而可以避免误操作，降低部署失败率。
> **提高安全性。**增量部署每次只会涉及到增量代码部分，不会直接暴露系统的整个代码部分更新，避免系统代码泄露的风险。

但增量部署也有缺点：

> **增量部署对于任何部署外的更新非常敏感，降低了部署流程的可预期性。**在日常工作中经常会出现为修复一个问题而临时修改运行环境的部署外更新，一旦这些部署外更新未及时考虑到增量计算中，非常容易导致之后的增量部署失败。全量部署过程则会完整执行完整个环境的配置、初始化以及部署工作，对于这些部署外更新有更好的容错性。
> **增量部署让回滚操作变得非常不容易。**每次回滚都需要逆向计算增量部分，然后做回滚操作。及时的备份策略有机会降低这个难道，但是如果需要回滚多个版本仍然是一个巨大的挑战。
> **增量部署无法直接满足从头部署最新系统的日常需求。**在云环境中资源的动态变化（尤其是虚机的增加和减少）逐渐会成为一个常态，用户时刻都可能面对两种场景的部署要求：从上个版本升级到最新版本，或者从零重新部署最新版本应用。显然，这两种部署需求一个增量更新，另一个则是全量更新。

（3）半增量部署 semi-increment
只更新近期有更改的文件。保存一个时间范围内的更新文件，最长一个月，集合了全量部署与增量部署的优点。压缩包小，对带宽的要求小，更新时间短，容错率高，可以实现一个月内的增量更新。
但同时也有缺点：
无法完成初始化的部署操作，若已部署过的系统，但不知道部署时的版本号，只能先进行一次全量部署，而且若因为网络原因导致部署失败，则没有提示，需要人工操作进行判断。

##1.2持续集成(Continous Intergration)
一个大项目是由多个模块组成的，每一个模块都有具体的小组负责开发，但有时候本模块独立测试正常，但与其他模块一起集成测试就会出问题。需要经常把所有模块集成在一起进行测试，尽早发现问题。关注点在于尽早发现项目整体运行问题，尽早解决。
##1.3持续交付(Continous Delievery)
用小版本不断进行快速迭代，不断收集用户反馈信息，用最快的速度改进优化。关注点在于研发团队的最新代码能够尽快让最终用户体验到。
##1.4当前现状分析
（1）开发人员少且项目工期紧
开发人员时间、地点不固定，每天还要进行旧模块的修改和新功能的提交，每个开发人员的时间都很宝贵。
（2）项目后期维护人员少但项目多
运维人员每天除了要处理现场工作，还要协助开发人员调试新功能，人员相对较少，但工作量大。
（3）客户的需求一变再变
功能需求是在项目进展过程中持续变化的，在使用中会不断有新的需求出现，这是不可避免的，唯一确定的是需求是持续变化的。只能建立统一的文档，平时由运维人员收集修改建议，论证后再录入待办任务，由部门领导安排优先级，设置好交付时间，具体责任到开发人员进行修改。
（4）传统的运维方式费时费力
每个人更新代码的经验不一样，开发人员对自己的代码比较了解，有时只需替换近期修改的文件即可，但大部分运维人员的开发水平相对较弱，只能全部进行文件的复制替换，不仅费时费力，而且容易出错，遇到网络和服务器的原因还容易导致更新失败。
##1.5自动化增量部署的优势
（1）降低风险
代码有更新后会第一时间在生产环境进行多次测试，降低代码错误导致的问题。有时候代码在开发人员本地的测试环境是没问题的，但生产环境与测试环境有可能不一样，只有通过生产环境的检验才能证明代码质量合格。
（2）减少重复劳动
每次更新时，编译、测试、打包、部署的操作都要重新进行一遍，让正常人做重复的事情，估计重复三次就不想再继续了。增量部署可以只更新增量的文件，相对全量部署能节约时间。按一个节点10分钟全量部署计算，提交一次代码就要部署一次，假如每天有10个节点，就是100分钟，这些还没算上更新失败的次数。而增量部署只需要1分钟1个节点。增量部署有以下几个优势：
部署速度快。增量部署每次仅对增量部分进行更新，无论是文件分发还是配置更新的内容都会更少，部署需要的时间也就相对较短。
减少变化量。增量部署可以减少对于整个系统的变化幅度，很多已经完成的配置工作不需要每次重复设置。从而可以避免误操作，降低部署失败率。
提高安全性。增量部署每次只会涉及到增量代码部分，不会直接暴露系统的整个代码，避免系统代码泄露的风险。
（3）快速部署
部署首先要保证稳定，再谈速度。简单来说自动部署就是把人工需要做的操作一步一步写下来，具体到每一步操作什么内容，再编写出部署脚本，期间有可能会出现各种干扰情况，需要先判断是否具备部署条件再进行部署。部署时会执行命令实现快速更新，下载更新包会受网络影响，时间不固定，但下载到本地后执行更新是瞬间的事情。增量部署能自动判断哪些节点需要更新，自动判断需要更新哪些文件。通过经常对代码进行小改动，从而避免整个系统出现大问题。
（4）增强项目的可见性
持续集成让我们能够注意到趋势并进行有效的决策。持续集成系统为项目构建状态和品质指标提供了及时的信息，并可以统计哪些模块的代码质量一般。
（5）建立团队对开发产品的信心
可以让开发人员清楚的知道每次构建的结果，从而得出他们对软件的改动造成了哪些影响。

#2持续部署系统

##2.1分析
手动的方法就不说了，曾经作为新手的我1小时才更新了四台，说多了都是泪。
[![V8NXb6.jpg](https://s2.ax1x.com/2019/06/02/V8NXb6.jpg)](https://imgchr.com/i/V8NXb6)
手动部署方式

自动部署后，开发人员只需要提交源码就行了，其他的流程都交给自动化部署工具执行。在这里没有使用钩子程序，而是每天定期执行的方式部署。
![V8UOzj.jpg](https://s2.ax1x.com/2019/06/02/V8UOzj.jpg)
自动部署方式

Web源码发布费时费力，需要先下载源码，进行编译，发布到本地，再将所有文件复制到服务器，但很多文件是不需要更新的。可以对流程进行优化。运行vs，获取最新源码，进行文件编译，发布到本地，按生成时间进行筛选，最终效果是获取指定SVN版本号间的改动文件，例如不同的发布环境下面的代码是根据不同的svn版本进行发布的，可以先查出来某一服务器上发布的svn版本，对旧的的svn版本和最新的svn版本做对比，筛选出有更新的文件，但操作难度太大参考：[从SVN导出指定版本号之间修改的文件][1]。可以退而求其次筛选出1个月内的最新文件，再分发给服务器进行更新，能大大减少更新文件的数量。
**原理：**进行更新文件的筛选，找出最新文件，压缩并上传到服务器。
**优化后的流程：**开发人员本地提交源码-自动化服务器定期获取源码并编译-筛查出更新包-同步到其他服务器上进行文件替换。
以代码服务器A为例，中转到B（B不是必须的），客户端C。A主机每天早上11点自动获取一次最新的代码，在本地编译完成以后生成一个月内待更新的文件压缩包，B主机通过网络共享方式获取压缩包并进行分发，C主机获取上游的压缩包并下载到本地进行解压，通过校验C主机本地版本号与A主机生成的最新版本号是否一致决定是否进行文件替换，若不一致则把所有web目录下指定的文件夹下面的文件替换为最新的文件。


##2.2准备工作
下面将使用发布平台，实现自动发布web端代码。
目前发现C:\Windows\Temp目录，jenkins会在这里新建一个bat文件，360安全卫士一直会阻止而导致无法生成升级包。先关闭安全卫士。
检查需要发布的项目是基于.NET4.0还是4.6发布的，本教程适合4.0，目前4.6暂未进行测试。
###2.2.1安装Jenkins工具
(1)下载Jenkins的windows安装包，进行安装。
(2)最好下载[net4.7][2]
(3)下载 Microsoft Build Tools 2013
 地址：[https://www.microsoft.com/zh-cn/download/details.aspx?id=40760][3]，下载文件为BuildTools_Full.exe
(4)安装7z压缩软件到C:\Program Files\7-Zip\目录。
（5）安装当时用的vs版本，如vs2010或2012

 Jenkins安装完以后设置用户名和密码，进行初始化。
 打开http://localhost:8080
 [![EhWVhj.md.jpg](https://s2.ax1x.com/2019/05/12/EhWVhj.jpg)](https://imgchr.com/i/EhWVhj)
 默认管理员是admin，默认密码是那个目录里的文件
先复制密码，粘贴以后继续
[![EhWMuV.jpg](https://s2.ax1x.com/2019/05/12/EhWMuV.jpg)](https://imgchr.com/i/EhWMuV)
![EhWuj0.jpg](https://s2.ax1x.com/2019/05/12/EhWuj0.jpg)
安装推荐的插件，全程需要联外网
![EhWAAg.jpg](https://s2.ax1x.com/2019/05/12/EhWAAg.jpg)
创建用户

若无法登录，则需要重启服务
用管理员身份启动cmd
进入jenkins安装根目录

    cd C:\"Program Files (x86)"\Jenkins

关闭命令：

    net stop jenkins

启动命令：

    net start jenkins

可以把这个命令写成bat文件，每次开机以后执行一次。
bat代码如下

    cd C:\"Program Files (x86)"\Jenkins
    ping 127.0.0.1 -n 10 >nul
    net stop jenkins
    ping 127.0.0.1 -n 10 >nul
    net start jenkins

项目目录C:\Program Files (x86)\Jenkins\workspace
可以手动把svn的源码拷贝到 C:\Program Files (x86)\Jenkins\workspace\任务名称 下面
比如任务名称为lyweb那就把所有源码拷贝到C:\Program Files (x86)\Jenkins\workspace\lyweb文件夹下面
这样就不会再下载一次了，第一次下载都很漫长。
而且使用自动下载的源码构建以后所有的文件都是最新的日期，可以先构建成功一次，再删除C:\Program Files (x86)\Jenkins\workspace\lyweb文件夹下面的文件，把开发人员本地的文件夹复制进去，再构建一次。
###2.2.2创建临时目录
D:\upload\ly项目发布程序\       为编译以后的文件
D:\upload\update\               筛选待压缩的文件
D:\upload\zip\                  进行压缩
D:\upload\sync\                 压缩后的存放位置                      这个里面是需要分发出去的upload.zip的包，此包是一个月内累计更新的文件，复制到服务器上替换就行了。分为全量包upload-full.zip，半增量包upload-semi.zip
##2.3插件安装
在面板配置里选择系统管理-插件管理 在可选插件里搜索MSBuild插件，并安装
安装完以后设置。
###2.3.1配置MSBuild的版本
【系统管理】->【全局工具配置】->【MSBuild】，点击【新增MSBuild】进行版本的添加，如下：
![EhW3EF.jpg](https://s2.ax1x.com/2019/05/12/EhW3EF.jpg)
其中name输入Version4
路径输入C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe
注意：如果是4.6的项目，参考：http://www.cnblogs.com/EasonJim/p/6038363.html
###2.3.2svn插件
还要在jenkins的配置里改svn的版本号，默认是1.4，我当前使用的是1.8
进入【系统管理】->【系统设置】把svn版本改一下。
![EhW9jP.jpg](https://s2.ax1x.com/2019/05/12/EhW9jP.jpg)
##2.4部署更新任务
###2.4.1general设置
在http://localhost:8080中新建任务
选择【构建一个自由风格的软件项目】，其余的不要去选择。
![EhWe9s.jpg](https://s2.ax1x.com/2019/05/12/EhWe9s.jpg)
###2.4.2源码设置
在这里需要先添加用户名和密码，保存后，再选择该用户名和密码。
![EhWncq.jpg](https://s2.ax1x.com/2019/05/12/EhWncq.jpg)
###2.4.3构建触发器
也可以选择钩子，但不能每次有人提交代码就更新，定时更新，进行小版本迭代会更好。
如0 11,23 * * * 就是每天11点和23点打包
![EhWiB8.jpg](https://s2.ax1x.com/2019/05/12/EhWiB8.jpg)
###2.4.4构建环境
都不选
###2.4.5构建
（1）执行清理
新建批处理命令
[![EhRo11.jpg](https://s2.ax1x.com/2019/05/12/EhRo11.jpg)](https://imgchr.com/i/EhRo11)
![EhWm3n.jpg](https://s2.ax1x.com/2019/05/12/EhWm3n.jpg)
先删除所有临时文件。代码如下：

    del /f /q /s D:\upload\sync\upload-semi.zip
    del /f /q /s D:\upload\sync\upload-full.zip
    del /f /q /s D:\upload\update\*.*
    RD  /s /q  D:\upload\update\
    mkdir D:\upload\update
    del /f /q /s  D:\upload\ly项目发布程序\*.*
    RD  /s /q D:\upload\ly项目发布程序\
    mkdir D:\upload\ly项目发布程序

(2)设置编译哪个项目
[![EhWPnf.jpg](https://s2.ax1x.com/2019/05/12/EhWPnf.jpg)](https://imgchr.com/i/EhWPnf)
MSBuild Version 选择Version4
![EhWFHS.jpg](https://s2.ax1x.com/2019/05/12/EhWFHS.jpg)
在 MSBuild Build File里选择`./src/LRSMES.WebUI/LRSMES.WebUI.csproj`   这里是项目名称，最好选择具体的哪个项目。
Command Line Arguments设置为 /t:Rebuild /p:Configuration=Release /p:TargetFrameworkVersion=v4.0 /p:OutputPath=D:\upload\ly项目发布程序;Configuration=Release
注意这个/t:Rebuild每条命令与下一条命令之间都有一个空格。
/t:Rebuild 表示每次都重建，不使用增量编译
/p:Configuration=Release 表示编译Release版本，
/p:TargetFrameworkVersion=v4.0表示编译的目标是.NET4.0
/p:OutputPath=D:\upload\ly项目发布程序;Configuration=Release 表示发布到d盘的某一目录下。
（3）再新建批处理筛选出最新的文件
以下是代码：

    @echo off
    set y=%date:~0,4%
    set m=%date:~5,2%
    set d=25
    set /a m-=1
    if %m%==0 set m=12&set /a y-=1
    if "%m%"=="1" (set mm1=01)
    if "%m%"=="2" (set mm1=02)
    if "%m%"=="3" (set mm1=03)
    if "%m%"=="4" (set mm1=04)
    if "%m%"=="5" (set mm1=05)
    if "%m%"=="6" (set mm1=06)
    if "%m%"=="7" (set mm1=07)
    if "%m%"=="8" (set mm1=08)
    if "%m%"=="9" (set mm1=09)
    if "%m%"=="10" (set mm1=10)
    if "%m%"=="11" (set mm1=11)
    if "%m%"=="12" (set mm1=12)
    echo 格式化以后月份为，前面加了0，例如05之类 %mm1%
    echo 上个月25日的日期是%y%-%mm1%=%d%
    echo 格式化日期mm-dd-yyyy后为%mm1%-%d%-%y%
    echo 压缩为全量更新包    
    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\Areas D:\upload\update\Areas /s /r /y
    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\bin D:\upload\update\bin /s /r /y
    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\Scripts D:\upload\update\Scripts /s /r /y 
    echo %SVN_REVISION% > D:\upload\update\revision.txt    
    call C:\"Program Files"\7-Zip\7z.exe a D:\lyweb\Resources\upload-full.zip D:\upload\update\
    echo 清空update目录下的全量文件       
    del /f /q /s D:\upload\update\*.*
    RD  /s /q  D:\upload\update\
    mkdir D:\upload\update
        
    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\Areas D:\upload\update\Areas /s /r /y /d:%mm1%-%d%-%y%
    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\bin D:\upload\update\bin /s /r /y /d:%mm1%-%d%-%y%
    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\Scripts D:\upload\update\Scripts /s /r /y /d:%mm1%-%d%-%y%
    

    

在这里解释一下为什么要得到上个月的日期，如当前日期是2019年5月25日，上个月的日期是2019年4月25日，若不写一个自动获取日期，则    echo d | xcopy D:\upload\ly项目发布程序\_PublishedWebsites\LRSMES.WebUI\bin D:\upload\update\bin /s /r /y /d:%mm1%-%d%-%y%命令执行时，最后面的/d:就只能把时间写死，成为/d:05-25-2019 这样才能避免可能出现的日期问题。至于_PublishedWebsites目录，则是本地发布以后就是在这个目录里，暂时未找到设置方法。echo d 和echo f的问题，由于复制文件时，系统会询问复制的是一个目录还是文件，分别对应d和f。后来发现这样有一个问题，就是若构建失败，有可能清空已下载好的源码，系统会重新下载一遍，导致该筛选方法失效，但一个月以后就正常了。临时的补救措施是手动把以前下载好的再覆盖一次源码。
先生成全量更新包upload-full.zip，再自动选择出一个月内的更新文件并打包为upload-semi.zip。
（4）最后新建一个批处理进行压缩

    echo [INFO] 压缩为半增量更新包
    echo %SVN_REVISION% > D:\upload\update\revision.txt
    echo f | xcopy "%JENKINS_HOME%\jobs\%JOB_NAME%\builds\%BUILD_ID%\changelog.xml" D:\upload\update\changelog.xml /s /e /r /y
    call C:\"Program Files"\7-Zip\7z.exe a D:\upload\sync\upload-semi.zip D:\upload\update\    
    echo f | xcopy D:\upload\sync\upload-semi.zip D:\lyWeb\Resources\upload-semi.zip /s /e /r /y /d
    echo f | xcopy D:\upload\update\revision.txt D:\lyWeb\revision.txt /s /e /r /y /d

需要7z压缩软件先安装好。C:\"Program Files"目录加引号是因为批处理在识别带空格的目录时必须要这样。
创建一个revision.txt文件，自动写入svn版本号。先用7z压缩软件压缩出upload.zip文件，再复制到能共享的目录里，如web的站点。
压缩一个作为同步到服务器上的包，命名必须固定如upload.zip，把文件也复制一份到web网站，这样其他主机可以访问http://XXXX/Resources/upload.zip地址获得最新的升级包了。
并把最新的版本号公布出去，别的主机访问http://XXXX/revision.txt就能获取最新的版本号。
（5）构建后通知
可以写一个邮件通知，若不成功则发邮件。
也可以自动发钉钉消息通知，下面是使用钉钉的尝试。
详见[\[钉钉通知系列\]Jenkins发布后自动通知][4]
![https://s2.ax1x.com/2019/05/13/E5Qma4.png][5]
正在测试[jenkins发送自定义格式和报错信息到钉钉指定人][6]
目标：获取当前任务的svn版本号和构建id

##2.5手动执行构建
###2.5.1自动生成升级包
![EhWlHU.jpg](https://s2.ax1x.com/2019/05/12/EhWlHU.jpg)
然后可以在左下角查看控制台的进度，一般10分钟内只能执行一次构建。
[![EhR20U.jpg](https://s2.ax1x.com/2019/05/12/EhR20U.jpg)](https://imgchr.com/i/EhR20U)
##2.6分发
###2.6.1客户端软件设置
其他服务器若需要同步最新的文件，需要安装7z软件到C:\Program Files\7-Zip目录，并下载wget.exe文件到C:\Windows\System32文件夹
下载wget的方法是 https://zhuanlan.zhihu.com/p/28826000
下载链接为https://eternallybored.org/misc/wget/
至于为什么不用windows自带的命令，主要是wget是linux系统下非常好用的一个命令，使用简单。
###2.6.2编写一键更新脚本
在d盘新建upload\temp文件夹，并创建一个名称为“自动更新web代码.bat”的批处理文件，改扩展名为bat。其中D:\pzWeb改为服务器上的web页面位置。
有时候若执行不了，则需要先右键以管理员权限运行一次。
下面是代码：

    @echo off
    echo 下载最新的版本号
    RD  /s /q  D:\upload\sync\
    mkdir D:\upload\sync\
    wget.exe -O D:\upload\sync\revision.txt http://xxxxxxx/revision.txt
    set /p var1=<D:\upload\sync\revision.txt
    echo 最新的版本号是%var1%
    
    echo 查看本地的版本号，先检查文件是否存在.
    if exist D:\pzWeb\revision.txt  (
        echo web目录下revision.txt文件已存在，可以进行进行版本号确认.
    ) else (
        echo web目录下无revision.txt，开始创建revision.txt文件并写入数值1.
        echo 1 > D:\pzWeb\revision.txt
    )
    set /p var2=<D:\pzWeb\revision.txt
    echo 本地的版本号是%var2%
    
    if %var2% geq %var1% (
        echo 本地的版本大于或等于svn版本，不需要更新。
    ) else (
        echo 执行更新，将下载最新的文件进行同步。
        del /f /q /s D:\upload\upload.zip
        RD  /s /q  D:\upload\temp\
        mkdir D:\upload\temp\
        if %var2% == 1 (
            echo 将进行全量更新，下载full更新包
            wget.exe -O D:\upload\upload.zip http://xxxxxxx/Resources/upload-full.zip     
        ) else (
            echo 只进行半增量更新，下载半增量更新包
            wget.exe -O D:\upload\upload.zip http://xxxxxxx/Resources/upload-semi.zip         
        )
        echo 解压缩到临时目录
        call C:\"Program Files"\7-Zip\7z.exe x D:\upload\upload.zip -oD:\upload\temp
        echo 正在部署web1
        echo d | xcopy D:\upload\temp\update\Areas D:\pzWeb\Areas /s /e /r /y /d
        echo d | xcopy D:\upload\temp\update\bin D:\pzWeb\bin /s /e /r /y /d
        echo d | xcopy D:\upload\temp\update\Scripts D:\pzWeb\Scripts /s /e /r /y /d
        echo 正在更新web1的版本号
        echo f | xcopy D:\upload\temp\update\revision.txt D:\pzWeb\revision.txt /s /e /r /y /d
    )
    echo xx项目部署完成。此脚本将于60秒后自动关闭！
    ping 127.0.0.1 -n 60 >nul



由于7z压缩时默认把上级文件夹名也带上了，导致解压缩后是在D:\upload\temp\update\目录。pzWeb为网站发布目录，需自行修改。根据本地的版本号和最新的版本号做对比，可以判断是否需要更新。更新时先清空临时目录下的所有文件，再下载最新的升级包到本地，然后解压缩，把解压以后的文件复制到web站点目录。这里加了一个/d参数，若服务器的文件比较旧，而且最新的升级包里有这个最新的文件，则进行更新，否则不会自动替换。若服务器上的文件被人为修改过，则需要看修改的是哪些文件，先备份出来，提交源码以后再执行一次同步。若服务器长时间未进行过同步，例如超过一个月，则无法自动同步一个月以上的文件，可以先手动完全同步一次，再使用自动同步的命令。
下载到本地以后，若有些目录不需要更新，如Areas\map目录，则把D:\upload\temp\update\Areas\map目录删除，删除命令是RD  /s /q D:\upload\temp\update\Areas\map，这样就不会同步该目录，删除的命令放在        call C:\"Program Files"\7-Zip\7z.exe x D:\upload\upload.zip -oD:\upload\temp 后面。


鉴于有些web会因为某些原因人工关闭站点，iis状态只能由手动控制，在这里不做任何操作。
参考：[iis用命令行重启其中一个网站][7]

停止： 

    C:\Windows\System32\inetsrv\appcmd.exe stop site “XXXX” 

注：”XXXX”网站，XXXX就是IIS的网站名称 
启动： 

    C:\Windows\System32\inetsrv\appcmd.exe start site “XXXX”

单独停止“应用程序池”： 

    C:\Windows\System32\inetsrv\appcmd.exe stop apppool /apppool.name:xxxx

单独启动“应用程序池”： 

    C:\Windows\System32\inetsrv\appcmd.exe start apppool /apppool.name:xxxx


这些服务器同步时需要360开白名单，或者手动运行一下bat文件，让360放行
运行无误后在服务器设置一个定时执行任务就行。

##2.7定期自动执行
默认每天中午11和下午23点服务器端自动获取一次源码并编译，客户端设置一个任务计划，每天0点执行，每6小时同步一次，全程不需要人员参与。

有一个方法是临时修改更新频率，适合修改较多，而且需要多次测试时使用。
非必须时请勿使用。
参考[Jenkins持续集成学习-Windows环境进行.Net开发3][32]
打开项目配置，构建触发器里勾选轮询SCM，可以选择	忽略钩子 post-commit。
日程表里写入  * * * * *
保存后会自动在开发人员提交代码后1分钟内自动开始构建，原理是通过轮询比较svn源码服务器与jenkins的本地代码，若svn有更新，则开始构建。
构建时间一般是5分钟，然后在待部署的服务器上设置计划任务，每10分钟更新一次。

##2.8手动执行
(1)若需要手动编译，则登录此站点，并点击构建。
![EhWlHU.jpg](https://s2.ax1x.com/2019/05/12/EhWlHU.jpg)
(2)然后可以在左下角查看控制台的进度，一般10分钟内只能执行一次构建。
[![EhR20U.jpg](https://s2.ax1x.com/2019/05/12/EhR20U.jpg)](https://imgchr.com/i/EhR20U)
(3)最后手动去其他web服务器上执行自动更新web代码.bat
(4)如何手动决定哪个服务器不要进行更新？
可以通过revision.txt文件控制。例如C电脑有一个web，正常更新时revision.txt文件是自动替换的，若某一时间段不准备更新此系统，则可以把本地的revision.txt的数值修改为很高，例如+1000，这样就不会自动更新。若想恢复更新，则把数值修改为大于1，且小于A主机获取的最新的svn版本号即可。如当前最新的版本是2333，不想更新则修改为3333，想恢复则修改为2-2332之间的任意数值。

##2.9基于jenkins的增量发布
准备测试基于jenkins的增量发布，关键字：增量 部署。目的：获取两个版本号间的增量更新的文件，不同服务器请求增量文件时能自动合成专用的压缩包，从而减小压缩文件的磁盘占用空间。
目前有一个思路，在d盘lyweb文件夹的Resources目录下新建一个目录，命名为ota,每次生成文件前都清空里面的文件，然后根据不同的版本时间生成多个压缩包如3389-3400.zip，客户端在请求时就直接下载对应的增量包就行。难点在于怎么获取不同的svn版本的创建时间，精确到秒。另外，版本库那么多，是不是都要生成？xcopy能直接精确到秒提取文件吗？或者获取不同版本之间的changlog，根据log知道哪些文件更新了。

##2.10若执行过程中出现问题
（1）最大的可能性是中途手动关闭，容易导致已下载好的svn源码被破坏。
注意：每次一定要等构建完成才能操作。若svn源码损坏，则jenkins会自动重新下载最新源码。但这些文件的创建时间就会变为最新，导致按创建时间进行筛选的方法失效。解决办法：先手动在本地生成升级包，手动给所有矿端更新一次。再使用[windows用powershell修改文档/文件夹创建时间、修改时间][8]的方法，创建一个批处理。

    @ECHO OFF
    powershell.exe -command "Get-Childitem -path 'D:\upload\ceshi\' -Recurse | foreach-object { $_.LastWriteTime = '01/11/2004 22:13:36'; $_.CreationTime = '01/11/2004 22:13:36' }" 
    PAUSE

这里的时间可以改为2个月前的就行，这样就会把创建时间统一修改。
(2)svn服务器由于网络原因无法连接会导致构建失败。不会有任何新文件替换。失败后会有钉钉提示，不影响已经做好的升级包。

#3.FAQ
##3.1手动执行是否会影响自动执行？
答：不影响，只不过会按时间有一个队列，若手动和自动同时开始，则肯定会有一个排序，第一个执行完以后再执行第二个，不会有冲突，从用户角度来看，就是连续构建了两次。
##3.2我手动执行过一次了，晚上自动执行时是不是会生成空的升级包？
答：生成的semi包中bll是每次构建都重新生成的，其他的是自动把近期更新的文件都添加好（上个月25日到当前时间之间），每次构建生成的包都差不多，只不过包含了近期的所有更新内容。
##3.3我在待部署的web上修改了一些内容，会不会受影响？
答：新增的文件夹和文件，但svn里没有，不会覆盖删除。修改以前的文件，则按文件修改时间前后进行判断，如今天17：00修改了本地内容，但svn里一直没改，下次构建时会检查svn是否已修改过，若没有修改过则不会覆盖本地。

参考：
[基于jenkins的增量发布][9]
[git如何实现增量上线 实现前端资源增量式更新的一种思路][10]
[SVN实现增量打包][11]
[jenkinse ant svn增量部署][12]
[增量部署还是全量部署，该如何选择？][13]
[jenkins+git+maven 增量部署思路以及相关脚本][14]
[自动化持续集成Jenkins][15]
[WEB前端优化必备压缩工具YUI-compressor详解][16]
[Node+UglifyJS批量压缩js][17]
[uglifyjs 合并压缩 js, clean-css 合并压缩css][18]
[windows用powershell修改文档/文件夹创建时间、修改时间][19]
[iis用命令行重启其中一个网站][20]
[Windows 远程停止iis服务 jenkins psexec][21]
[我的jenkins自动部署方案演进史][22]
[持续集成工具Jenkins结合SVN的安装和使用][23]
[IIS应用程序池监控][24]
[【翻译】使用PowerShell获取网站运行时数据][25]
[Jenkins+MSbuild+SVN实现dotnet持续集成 快速搭建持续集成环境][26]
[Jenkins搭建.NET自动编译测试与发布环境][27]
[用 MSBuild 和 Jenkins 搭建持续集成环境（1）][28]
[Jenkins配置基于角色的项目权限管理][29]
[Jenkins使用教程之用户权限管理（包含插件的安装）][30]
[批处理如何运行远程机子的exe文件？][31]
[Jenkins持续集成学习-Windows环境进行.Net开发3][32]


  [1]: https://zhengdl126.iteye.com/blog/1154427
  [2]: https://www.microsoft.com/zh-CN/download/details.aspx?id=55170
  [3]: https://www.microsoft.com/zh-cn/download/details.aspx?id=4076
  [4]: https://blog.csdn.net/workdsz/article/details/77531802
  [5]: https://s2.ax1x.com/2019/05/13/E5Qma4.png
  [6]: https://blog.csdn.net/zhangxiaofan666/article/details/79765121
  [7]: https://blog.csdn.net/zzy5066/article/details/78181796
  [8]: https://blog.csdn.net/u012223913/article/details/72123906
  [9]: https://blog.csdn.net/sjbup/article/details/49634121
  [10]: https://blog.csdn.net/peterxiaoq/article/details/76173699
  [11]: https://blog.csdn.net/l05199179/article/details/80403407
  [12]: https://blog.csdn.net/flowerprince88/article/details/79128475
  [13]: http://blog.fit2cloud.com/2016/01/15/deployment-methodologies.html
  [14]: https://www.cnblogs.com/ai594ai/p/6490621.html
  [15]: https://www.cnblogs.com/zdz8207/p/5036966.html
  [16]: https://blog.csdn.net/baidu_25343343/article/details/53396756
  [17]: https://blog.csdn.net/zhangqun23/article/details/86496382
  [18]: https://www.cnblogs.com/sese/p/10138995.html
  [19]: https://blog.csdn.net/u012223913/article/details/72123906
  [20]: https://blog.csdn.net/zzy5066/article/details/78181796
  [21]: https://blog.csdn.net/ma_jiang/article/details/53955504
  [22]: https://blog.csdn.net/shan9liang/article/details/21597551
  [23]: https://blog.csdn.net/zxd1435513775/article/details/80618640
  [24]: https://www.cnblogs.com/aaronguo/p/3853009.html
  [25]: https://www.cnblogs.com/daizhj/archive/2008/12/11/1352718.html
  [26]: https://www.cnblogs.com/linJie1930906722/p/5966581.html
  [27]: https://blog.csdn.net/wangjia184/article/details/18365553
  [28]: https://www.infoq.cn/article/MSBuild-1/
  [29]: https://www.cnblogs.com/gao241/archive/2013/03/20/2971416.html
  [30]: https://www.jianshu.com/p/7e148bcfb96e
  [31]: http://www.bathome.net/thread-24468-1-1.html
  [32]: https://www.cnblogs.com/Jack-Blog/p/10331263.html