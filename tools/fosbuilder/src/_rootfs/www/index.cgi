#!/bin/bash
. /usr/share/foguefi/funcs.sh

# FOG Status file : /tmp/status2.fog
# Alert file : /tmp/alert_msg.txt


# Current Computername in FOG
_compname=""

# Current IP Address of this client
_compipaddr="$(getIPAddresses)"

# Current Task ($type:up/down $mode:clamav/manreg/autoreg/....)
_curtask=""

# Base URL of ttyd
_remoteurl="https://${_compipaddr}:81"

_compname="$(hostname -s)"


# Get the friendly task name : 
FLAG_scheduledTask=0
if [[ -n $type && -n $osid ]]; then
    # Si $type est définie {up/down} && que $osid est définie (peut importe $mode), il y a quelque-chose à faire
    #echo "Tache programmée (SERVEUR/PROGRAMMEE)"
    FLAG_scheduledTask=1 # 1 = Tache programmée
fi
if [[ -z $type && -n $mode ]]; then
    # Si $mode est définie {clamav, manreg...} && que $type n'est pas définie, il y a un mode à traîter
    #echo "Tache programmée (MODE)"
    FLAG_scheduledTask=2 # 2 = Mode programmée
fi
if [[ "$FLAG_scheduledTask" -ne 0 ]]; then
    # Task/Mode detected, show a way to interrupt a Fog process
    friendlyOperationName=''
    case "$FLAG_scheduledTask" in
        1) # up/down
            case "$type" in
                up)
                    friendlyOperationName='\033[30;103m upload image \033[0m'
                    ;;
                down)
                    if [[ "$mc" == "yes" ]]; then # Mode multicast
                        friendlyOperationName='\033[30;42m download image (Multicast)\033[0m'
                    else
                        friendlyOperationName='\033[30;42m download image \033[0m'
                    fi
                    ;;
                *)
                    friendlyOperationName="?? $type"
                    ;;
            esac
        ;;
        2) # autoreg/manreg/clamav/memtest/...
            case "$mode" in
                sysinfo)
                    friendlyOperationName='basic system information'
                    ;;
                clamav)
                    friendlyOperationName='virus scan' # Deprecated by the FOG Team
                    ;;
                onlydebug)
                    friendlyOperationName='debug'
                    ;;
                checkdisk)
                    friendlyOperationName='test disk'
                    ;;
                badblocks)
                    friendlyOperationName='disk surface test'
                    ;;
                photorec)
                    friendlyOperationName='recover files'
                    ;;
                winpassreset)
                    friendlyOperationName='\033[97;41m reset Windows passwords \033[0m'
                    ;;
                wipe)
                    friendlyOperationName='\033[97;41m wipe hard disk \033[0m'
                    ;;                                                
                autoreg)
                    friendlyOperationName='automatic inventory and registration'
                    ;;
                manreg)
                    friendlyOperationName='manual inventory and registration'
                    ;;
                *)
                    friendlyOperationName="??? $mode"
                    ;;
            esac
            ;;
    esac
fi
_curtask="$type"
if [[ -z "$_curtask" ]]; then _curtask="$mode"; fi
if [[ -z "$_curtask" ]]; then _curtask="$menutype"; fi
if [[ -z "$_curtask" ]]; then _curtask="(none)"; fi

# Color palette
_showprogress=0
case "$_curtask" in
    up)
        _syscol='bg-warning'
        _showprogress=1
        ;;
    
    down)
        _syscol='bg-success'
        _showprogress=1
        ;;

    *)
        _syscol='bg-primary'
        ;;
esac

status=$(tail -n 2 "/tmp/status2.fog" 2>/dev/null | head -n 1 2>/dev/null)
if [[ -z "$status" ]]; then status=$(tail -n 2 "/tmp/status2_bak.fog" 2>/dev/null | head -n 1 2>/dev/null); else _NO_STATUS=0; fi
if [[ -z "$status" ]]; then _NO_STATUS=1; else _NO_STATUS=0; fi

if [[ "$_NO_STATUS" -eq 0 ]]; then
    echo "$status" >> "/tmp/status2_bak.fog";
    cat /dev/null > "/tmp/status2.fog" 2>/dev/null
    oldIFS="$IFS"
    IFS='@' read -r -a fosstatus <<< "$status"
    IFS="$oldIFS"
    # ${fosstatus[0]} -> (String) Current speed (Byte per minute)
    # ${fosstatus[1]} -> (String) time Elapsed 
    # ${fosstatus[2]} -> (String) time Remaining 
    # ${fosstatus[3]} -> (String) dataCopied 
    # ${fosstatus[4]} -> (String) dataTotal 
    # ${fosstatus[5]} -> (Num) Percent 
    # ${fosstatus[6]} -> (Float) Image size 
fi



echo "Content-type: text/html"
echo ""


# !!!!!!!!!!! HEADER !!!!!!!!!!!!!!
cat <<FINTEXTE
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="refresh" content="10" />
    <title>
FINTEXTE
# ---- TITLE
if [[ "$_NO_STATUS" -eq 0 ]]; then
    echo "FOS:${fosstatus[5]}%"
else
    if [[ -z "$friendlyOperationName" ]]; then
        friendlyOperationName="None"
    fi
    echo "FOS:${friendlyOperationName}"
fi
cat <<FINTEXTE
</title>
    <link rel="stylesheet" href="/bootstrap.css" />
  </head>
FINTEXTE

cat <<FINTEXTE
<body>
      <nav class="navbar navbar-expand-lg bg-primary" data-bs-theme="dark">
        <div class="container-fluid">
          <img src="/foglogo.png" align="right" height="40px">&nbsp;&nbsp;
          <a class="navbar-brand" href="#">FOS Client</a>
          <div class="collapse navbar-collapse" id="navbarColor01">
            <ul class="navbar-nav me-auto">
FINTEXTE
echo "<li class='nav-item'><a class='nav-link' href='${_remoteurl}' target="_blank">System console</a></li>"
cat <<FINTEXTE
            </ul>
          </div>
        </div>
      </nav>
    <div class="container">
FINTEXTE

if [[ -r "/tmp/alert_msg.txt" ]]; then
    echo '<div class="alert alert-dismissible alert-warning">'
    echo '<h4 class="alert-heading">Warning :</h4><p class="mb-0">'
    cat /tmp/alert_msg.txt
    echo '</p></div>'
fi


cat <<FINTEXTE
      <header role="banner">
        <h1>FOS Client</h1>
        <p>
FINTEXTE

echo "Operation <span class='badge ${_syscol}'>${friendlyOperationName}</span> on <b>${_compname}</b> (${_compipaddr})"
cat <<FINTEXTE  
        </p>
        <hr />
      </header>
FINTEXTE

if [[ "$_showprogress" -eq 1 ]]; then
    if [[ "$_NO_STATUS" -eq 0 ]]; then
        echo '<div class="progress">'
        echo "<div class='progress-bar progress-bar-striped progress-bar-animated ${_syscol}' role='progressbar' aria-valuenow='${fosstatus[5]}' aria-valuemin='0' aria-valuemax='100' style='width: ${fosstatus[5]}%;'></div>"
        echo '</div>'
        echo '</br><p>'
        echo " Current speed : ${fosstatus[0]}&nbsp;&nbsp;"
        echo " Remaining time : ${fosstatus[2]} (${fosstatus[1]} elapsed)"
        echo '</p>'
    else
        echo '<div class="progress">'
        echo "<div class='progress-bar progress-bar-striped progress-bar-animated ${_syscol}' role='progressbar' aria-valuenow='0' aria-valuemin='0' aria-valuemax='100' style='width: 0%;'></div>"
        echo '</div>'
        echo '</br><p>'
        echo " Current speed : ???&nbsp;&nbsp;"
        echo " Remaining time : ??? (??? elapsed)"
        echo '</p>'
    fi
else
    echo '</br>'
fi

echo "<a href='${_remoteurl}?arg=2+FOS+screen+console' target="_blank"> <button type='button' class='btn btn-primary'>FOS Console</button></a>"

echo "<p class='bs-component' style='float: right;'>"
echo "<a href='${_remoteurl}?arg=3+Force+reboot' target="_blank"> <button type='button' class='btn btn-danger'>Force Reboot</button></a>"
echo '</p>'
# ------ STATS Systèmes
echo '<br><br><hr />'
echo '<h4> uptime </h4><pre>'
uptime
echo '</pre>'
echo '<h4> free -h </h4><pre>'
free -h
echo '</pre>'
echo '<h4> df -h </h4><pre>'
df -h
echo '</pre>'


cat <<FINTEXTE
    </div>
  </body>
</html>
FINTEXTE





exit 0