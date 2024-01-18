#! /bin/bash

osDetail(){
  case "$(uname -s)" in
    Darwin)
      OS_NAME="Darwin"
	  OS_VERSION=$(uname -r)
	  ;;
    *)
	  OS_NAME=$(cat /etc/*release | grep NAME= | awk '!/CODENAME/ && !/PRETTY_NAME/' | awk '{ print $1 }' | awk -F'=' '{ print $2 }' | sed "s/\"//g")
	  OS_NAME=$(echo $OS_NAME | awk '{ print $1 }')
	  OS_VERSION=$(cat /etc/*release | grep VERSION_ID= | awk '{ print $1 }' | awk -F'=' '{ print $2 }' | sed "s/\"//g")
	  ;;
  esac
}

rpmUninstall(){
   yum remove falcon-sensor -y $1
}

aptUninstall(){
   apt-get -y remove falcon-sensor $1
}

osDetail
case "$OS_NAME" in
    deb?*|Deb?*|ubu?*|Ubu?* )
        PACKAGER="apt"
        ;;
    rhel|RHEL|red?*|cent?*|Red?*|Cent?*|ora?*|Ora?* )
        PACKAGER="yum"
        ;;
    sles|SLES )
        PACKAGER="zypper"
        ;;
    amz?*|Ama?*|ama?* )
        PACKAGER="yum"
        ;;
    win?*|Win?* )
        PACKAGER="exe"
        ;;
esac

case "$PACKAGER" in
    apt)
        aptUninstall $SSM_LINUX_UNINSTALLPARAMS
        ;;
    yum|zypper)
        rpmUninstall $SSM_LINUX_UNINSTALLPARAMS
        ;;
esac
