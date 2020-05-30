#!/usr/bin/env bash

##################################################################################
#                                                                                #
#  Installs CSGO Server Launcher                                                 #
#                                                                                #
#  Copyright (C) 2013-2020 CrazyMax                                              #
#                                                                                #
#  Counter-Strike : Global Offensive Server Launcher is free software; you can   #
#  redistribute it and/or modify it under the terms of the GNU Lesser General    #
#  Public License as published by the Free Software Foundation, either version 3 #
#  of the License, or (at your option) any later version.                        #
#                                                                                #
#  Counter-Strike : Global Offensive Server Launcher is distributed in the hope  #
#  that it will be useful, but WITHOUT ANY WARRANTY; without even the implied    #
#  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the      #
#  GNU Lesser General Public License for more details.                           #
#                                                                                #
#  You should have received a copy of the GNU Lesser General Public License      #
#  along with this program. If not, see http://www.gnu.org/licenses/.            #
#                                                                                #
#  Website: https://github.com/crazy-max/csgo-server-launcher                    #
#                                                                                #
##################################################################################

# Check distrib
if ! command -v apt-get &> /dev/null; then
  echo "ERROR: OS distribution not supported..."
  exit 1
fi

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script as root..."
  exit 1
fi

### Vars
shellPath=$(dirname $(readlink -f "$0"))
user="steam"
home="/home/$user"
version=overlay_v1.0.2
downloadUrl="https://github.com/TKaxv-7S/csgo-server-launcher-use-the-overlayFS/releases/download/$version"
scriptPath="$home/csgo-server-launcher"
steamcmdPath="$home/steamcmd"
sourcePath="$home/sourcepath"
rootPath="$sourcePath/root"
pluginPath="$sourcePath/plugin"
confPath="$sourcePath/csgo-server-launcher.conf"
cfgPath="$sourcePath/csgoserver.cfg"
ipAddress=$(curl ipinfo.io/ip)
if [ -z "$ipAddress" ]; then
  echo "ERROR: Cannot retrieve your public IP address..."
  exit 1
fi

### Start
echo ""
echo "Starting CSGO Server Launcher install (${version})..."
echo ""

echo "Adding i386 architecture..."
dpkg --add-architecture i386 >/dev/null
if [ "$?" -ne "0" ]; then
  echo "ERROR: Cannot add i386 architecture..."
  exit 1
fi

echo "Installing required packages..."
apt-get update >/dev/null

apt-get install -y -q libc6-i386 lib32stdc++6 lib32gcc1 lib32ncurses? lib32z1 curl gdb screen tar >/dev/null
if [ "$?" -ne "0" ]; then
  echo "ERROR: Cannot install required packages..."
  exit 1
fi

echo "Checking $user user exists..."
getent passwd ${user} >/dev/null
if [ "$?" -ne "0" ]; then
  echo "Adding $user user..."
  useradd -m ${user}
  if [ "$?" -ne "0" ]; then
    echo "ERROR: Cannot add user $user..."
    exit 1
  fi
#else
#  mkdir -p ~${user}
fi

echo "创建 $sourcePath 文件夹..."
mkdir -p $sourcePath

echo "创建 $rootPath 文件夹..."
mkdir -p "$rootPath"

echo "创建 $pluginPath 文件夹..."
mkdir -p "$pluginPath"

echo "创建 $steamcmdPath 文件夹..."
mkdir -p "$steamcmdPath"

if [ ! -f $scriptPath ]; then
  if [ -f $shellPath/csgo-server-launcher ]
  then
    echo "移动csgo-server-launcher文件至 $scriptPath ..."
    mv $shellPath/csgo-server-launcher $scriptPath
  else
    echo "下载csgo-server-launcher文件至 $scriptPath ..."
    curl -sSLk ${downloadUrl}/csgo-server-launcher -o ${scriptPath}
  fi
fi
if [ "$?" -ne "0" ]; then
  echo "ERROR: Cannot download CSGO Server Launcher script..."
  exit 1
fi

echo "Chmod script..."
chmod +x ${scriptPath}
if [ "$?" -ne "0" ]; then
  echo "ERROR: Cannot chmod CSGO Server Launcher script..."
  exit 1
fi

#安装时不设置自启
#echo "Install System-V style init script link..."
#update-rc.d csgo-server-launcher defaults >/dev/null
#if [ "$?" -ne "0" ]; then
#  echo "ERROR: Cannot install System-V style init script link..."
#  exit 1
#fi

if [ ! -f $confPath ]; then
  if [ -f $shellPath/csgo-server-launcher.conf ]
  then
    echo "移动csgo-server-launcher.conf文件至 $confPath ..."
    mv $shellPath/csgo-server-launcher.conf $confPath
  else
    echo "下载csgo-server-launcher.conf文件至 $confPath ..."
    curl -sSLk ${downloadUrl}/csgo-server-launcher.conf -o ${confPath}
  fi
fi

if [ ! -f $cfgPath ]; then
  if [ -f $shellPath/csgoserver.cfg ]
  then
    echo "移动csgoserver.cfg文件至 $cfgPath ..."
    mv $shellPath/csgoserver.cfg $cfgPath
  else
    echo "下载csgoserver.cfg文件至 $cfgPath ..."
    curl -sSLk ${downloadUrl}/csgoserver.cfg -o ${cfgPath}
  fi
fi

if [ "$?" -ne "0" ]; then
  echo "ERROR: Cannot download CSGO Server Launcher configuration..."
  exit 1
fi

#此处不可修改server文件夹，会触发overlayFS修改复制，导致服务程序大量复制！
chown -R ${user}:${user} "$sourcePath"
chown -R ${user}:${user} "$steamcmdPath"
chown ${user}:${user} "$scriptPath"

echo "Updating USER in config file..."
sed "s#USER=\"steam\"#USER=\"$user\"#" -i "$confPath"

echo "Updating IP in config file..."
sed "s#IP=\"0.0.0.0\"#IP=\"$ipAddress\"#" -i "$confPath"

#echo "Updating DIR_STEAMCMD in config file..."
#sed "s#DIR_STEAMCMD=\"$HOME/steamcmd\"#DIR_STEAMCMD=\"$steamcmdPath\"#" -i "$confPath"

echo "设置每天凌晨4点自动更新服务器"
crontabCommand="0 4 * * * ${user} ${home}/csgo-server-launcher update > /dev/null 2>&1"
crontabNumber=$(grep -n "${home}/csgo-server-launcher update > /dev/null 2>&1" /etc/crontab |awk -F ":" '{print $1}')
if [ -n "$crontabNumber" ]
then
  sed -i "${crontabNumber}c $crontabCommand" /etc/crontab
else
  echo "$crontabCommand" >> /etc/crontab
fi

echo ""
echo "Done!"
echo ""

echo "DO NOT FORGET to edit the configuration in '$confPath'"
echo "Then type:"
echo " 命令 '.$scriptPath create' 安装steam和csgo"
echo " 命令 '.$scriptPath init <servername>' 初始化使用overlayFS的服务器"
echo ""
