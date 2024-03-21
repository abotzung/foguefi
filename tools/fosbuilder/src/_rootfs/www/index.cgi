#!/bin/bash
. /usr/share/fog/lib/funcs.sh

# FOG Status file : /tmp/status2.fog
# Alert file : /tmp/alert_msg.txt





getIPAddresses() {
    read ipaddr <<< $(/sbin/ip -4 -o addr | awk -F'([ /])+' '/global/ {print $4}' | tr '[:space:]' '|' | sed -e 's/^[|]//g' -e 's/[|]$//g')
    echo $ipaddr
}

fog_compName () {
    ######## Donne le nom du pc à l'aide du serveur FOG ####
    # Renvoie ***Unknown*** si l'ordinateur n'existe pas
    MONuuid=$(dmidecode -s system-uuid)
    MONuuid=${sysuuid,,}
    MONmac=$(getMACAddresses)
    DoCurl=$(curl -Lks --data "sysuuid=${MONuuid}&mac=$MONmac" "${web}service/hostname.php" -A '')

    if [[ $DoCurl == *"#!ok="* ]]; then
        IFS=$'\n'
        for line in $DoCurl; do
            if [[ $line == *"#!ok="* ]]; then
                line2=$(echo "$line" | sed -r 's,\t,,g')
                line2=${line2/=/|}
                _compname=$(awk -F\|  '{print $2}' <<< $line2)
            fi
        done
    else
        _compname="***Unknown***"
    fi
}

# Current Computername in FOG
_compname=""

# Current IP Address of this client
_compipaddr="$(getIPAddresses)"

# Current Task ($type:up/down $mode:clamav/manreg/autoreg/....)
_curtask=""

# Base URL of ttyd
_remoteurl="http://${_compipaddr}:81"

if [[ ! -r "/tmp/compname" ]]; then
    fog_compName
    echo "$_compname" > /tmp/compname
else
    _compname=$(cat /tmp/compname)
fi


_curtask="$type"
if [[ -z "$_curtask" ]]; then _curtask="$mode"; fi
if [[ -z "$_curtask" ]]; then _curtask="$menutype"; fi
if [[ -z "$_curtask" ]]; then _curtask="(none)"; fi

# Color palette
case "$_curtask" in
    up)
        _syscol='bg-warning'
        ;;
    
    down)
        _syscol='bg-success'
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
    echo "FOS:${_curtask}"
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

echo "Operation <span class='badge ${_syscol}'>${_curtask}</span> on <b>${_compname}</b> (${_compipaddr})"
cat <<FINTEXTE  
        </p>
        <hr />
      </header>
FINTEXTE

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


echo "<a href='${_remoteurl}?arg=FOSConsole' target="_blank"> <button type='button' class='btn btn-primary'>FOS Console</button></a>"
echo "<a href='${_remoteurl}?arg=VNCServer' target="_blank"> <button type='button' class='btn btn-primary'>Restart VNC Server</button></a>"

echo "<p class='bs-component' style='float: right;'>"
echo "<a href='${_remoteurl}?arg=RebootNow' target="_blank"> <button type='button' class='btn btn-danger'>Force Reboot</button></a>"
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
