#!/bin/bash

while [[ -z "$tk" ]]; do
    echo "Bot token: "
    read -r tk
    [[ -z "$tk" ]] && unset tk
done

while [[ -z "$chatid" ]]; do
    echo "Chat id: "
    read -r chatid
    [[ ! $chatid =~ ^\-?[0-9]+$ ]] && unset chatid
done

echo "Caption: "
read -r caption

while true; do
    echo "Cronjob (minute hour): "
    read -r minute hour
    if [[ $minute =~ ^[0-9]+$ ]] && [[ $hour =~ ^[0-9]+$ ]]; then
        cron_time="*/${minute} */${hour} * * *"
        break
    fi
done

while [[ -z "$xmhs" ]]; do
    echo "x-ui or s-ui or marzban or hiddify? [x/s/m/h]"
    read -r xmhs
    [[ ! $xmhs =~ ^[xmhs]$ ]] && unset xmhs
done

TS=$(date +%Y%m%d-%H%M%S)
WORKDIR="/root/ac-backup-${xmhs}-${TS}"
mkdir -p "$WORKDIR"

ZIPFILE="$WORKDIR/ac-backup-${xmhs}.zip"
MVZIP="$WORKDIR/ac-backup-${xmhs}-mv.zip"

if [[ "$xmhs" == "m" ]]; then
    sed -i -e 's/\s*=\s*/=/' /opt/marzban/.env
    source /opt/marzban/.env

    docker exec marzban-mysql-1 bash -c "mkdir -p /var/lib/mysql/db-backup"

    docker exec marzban-mysql-1 bash -c "
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e 'SHOW DATABASES;' | grep -Ev 'Database|mysql|sys|performance_schema|information_schema' | while read db; do
        mysqldump -uroot -p$MYSQL_ROOT_PASSWORD --databases \$db > /var/lib/mysql/db-backup/\$db.sql
    done
    "

    zip -5r "$ZIPFILE" /opt/marzban /var/lib/marzban /opt/marzban/.env /var/lib/mysql/db-backup

elif [[ "$xmhs" == "x" || "$xmhs" == "s" ]]; then
    db=$(find / -name "*-ui.db" 2>/dev/null | head -n1)
    cfg=$(find / -name "config.json" 2>/dev/null | head -n1)
    zip -5 "$ZIPFILE" "$db" "$cfg"

elif [[ "$xmhs" == "h" ]]; then
    cd /opt/hiddify-manager/hiddify-panel || exit 1
    python3 -m hiddifypanel backup
    latest=$(ls -t backup/*.json | head -n1)
    zip -5 "$ZIPFILE" "$latest"
fi

zip -s 45m "$MVZIP" "$ZIPFILE"
rm -f "$ZIPFILE"

for f in "$WORKDIR"/ac-backup-${xmhs}-mv.zip "$WORKDIR"/ac-backup-${xmhs}-mv.z*; do
    [[ -f "$f" ]] || continue
    curl -s -F chat_id="$chatid" \
         -F document=@"$f" \
         https://api.telegram.org/bot${tk}/sendDocument
    sleep 2
done

find /root -maxdepth 1 -type d -name "ac-backup-${xmhs}-*" -mtime +2 -exec rm -rf {} \;

{ crontab -l 2>/dev/null; echo "${cron_time} /bin/bash $0 >/dev/null 2>&1"; } | crontab -
#!/bin/bash

while [[ -z "$tk" ]]; do
    echo "Bot token: "
    read -r tk
    if [[ $tk == $'\0' ]]; then
        echo "Invalid input. Token cannot be empty."
        unset tk
    fi
 done

while [[ -z "$chatid" ]]; do
    echo "Chat id: "
    read -r chatid
    if [[ $chatid == $'\0' ]]; then
        echo "Invalid input. Chat id cannot be empty."
        unset chatid
    elif [[ ! $chatid =~ ^\-?[0-9]+$ ]]; then
        echo "${chatid} is not a number."
        unset chatid
    fi
 done

echo "Caption (for example, your domain, to identify the database file more easily): "
read -r caption

while true; do
    echo "Cronjob (minutes and hours) (e.g : 30 6 or 0 12) : "
    read -r minute hour
    if [[ $minute == 0 ]] && [[ $hour == 0 ]]; then
        cron_time="0 0 * * *"
        break
    elif [[ $minute == 0 ]] && [[ $hour =~ ^[0-9]+$ ]] && [[ $hour -lt 24 ]]; then
        cron_time="0 */${hour} * * *"
        break
    elif [[ $hour == 0 ]] && [[ $minute =~ ^[0-9]+$ ]] && [[ $minute -lt 60 ]]; then
        cron_time="*/${minute} * * * *"
        break
    elif [[ $minute =~ ^[0-9]+$ ]] && [[ $hour =~ ^[0-9]+$ ]] && [[ $hour -lt 24 ]] && [[ $minute -lt 60 ]]; then
        cron_time="*/${minute} */${hour} * * *"
        break
    else
        echo "Invalid input, please enter a valid cronjob format (minutes and hours, e.g: 0 6 or 30 12)"
    fi
 done

while [[ -z "$xmhs" ]]; do
    echo "x-ui or s-ui or marzban or hiddify? [x/s/m/h] : "
    read -r xmhs
    if [[ $xmhs == $'\0' ]]; then
        echo "Invalid input. Please choose x,s, m or h."
        unset xmhs
    elif [[ ! $xmhs =~ ^[xmhs]$ ]]; then
        echo "${xmhs} is not a valid option. Please choose x, m or h."
        unset xmhs
    fi
 done

while [[ -z "$crontabs" ]]; do
    echo "Would you like the previous crontabs to be cleared? [y/n] : "
    read -r crontabs
    if [[ $crontabs == $'\0' ]]; then
        echo "Invalid input. Please choose y or n."
        unset crontabs
    elif [[ ! $crontabs =~ ^[yn]$ ]]; then
        echo "${crontabs} is not a valid option. Please choose y or n."
        unset crontabs
    fi
 done

if [[ "$crontabs" == "y" ]]; then
    sudo crontab -l | grep -vE '/root/ac-backup.+\.sh' | crontab -
fi

TS=$(date +%Y%m%d-%H%M%S)
WORKDIR="/root/ac-backup-${xmhs}-${TS}"
mkdir -p "$WORKDIR"
ZIPFILE="$WORKDIR/ac-backup-${xmhs}.zip"
MVZIP="$WORKDIR/ac-backup-${xmhs}-mv.zip"

if [[ "$xmhs" == "m" ]]; then
    if dir=$(find /opt /root -type d -iname "marzban" -print -quit); then
      echo "The folder exists at $dir"
    else
      echo "The folder does not exist."
      exit 1
    fi

    if [ -d "/var/lib/marzban/mysql" ] || [ -d "/var/lib/mysql/marzban" ]; then
        path=""
        if [ -d "/var/lib/marzban/mysql" ]; then
          path="/var/lib/marzban/mysql"
        elif [ -d "/var/lib/mysql/marzban" ]; then
          path="/var/lib/mysql/marzban"
        else
          echo "Neither path exists."
          exit 1
        fi

        sed -i -e 's/\s*=\s*/=/' -e 's/\s*:\s*/:/' -e 's/^\s*//' /opt/marzban/.env
        docker exec marzban-mysql-1 bash -c "mkdir -p /var/lib/mysql/db-backup"
        source /opt/marzban/.env

        cat > "$path/ac-backup.sh" <<EOL
#!/bin/bash
USER="root"
PASSWORD="$MYSQL_ROOT_PASSWORD"
databases=\$(mysql -h 127.0.0.1 --user=\$USER --password=\$PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
for db in \$databases; do
    if [[ "\$db" != "information_schema" ]] && [[ "\$db" != "mysql" ]] && [[ "\$db" != "performance_schema" ]] && [[ "\$db" != "sys" ]] ; then
        echo "Dumping database: \$db"
        mysqldump -h 127.0.0.1 --force --opt --user=\$USER --password=\$PASSWORD  --routines --databases \$db > /var/lib/mysql/db-backup/\$db.sql
    fi
 done
EOL

        chmod +x "$path/ac-backup.sh"
        docker exec marzban-mysql-1 bash -c "/var/lib/mysql/ac-backup.sh"
        zip -5r "$ZIPFILE" /opt/marzban/* /var/lib/marzban/* /opt/marzban/.env -x $path/*
        zip -5r "$ZIPFILE" $path/db-backup/*
        rm -rf "$path/db-backup/*"
    fi

elif [[ "$xmhs" == "x" || "$xmhs" == "s" ]]; then
    dbDir=$(find /etc /opt/freedom /usr/local -type d \( -iname "x-ui*" -o -iname "s-ui" \) -print -quit 2>/dev/null)
    if [[ -n "${dbDir}" ]]; then
        if [[ $dbDir == "/opt/freedom/x-ui"* ]]; then
            dbDir="${dbDir}/db/x-ui.db"
        elif [[ $dbDir == "/usr/local/s-ui" ]]; then
            dbDir="${dbDir}/db/s-ui.db"
        else
            dbDir="${dbDir}/x-ui.db"
        fi
    fi
    configDir=$(find /usr/local -type d -iname "x-ui*" -print -quit 2>/dev/null)
    [[ -n "${configDir}" ]] && configDir="${configDir}/config.json" || configDir=""
    zip -5 "$ZIPFILE" "$dbDir" "$configDir"

elif [[ "$xmhs" == "h" ]]; then
    cd /opt/hiddify-manager/hiddify-panel/ || exit 1
    backupCommand=""
    [ -f backup.sh ] && backupCommand="bash backup.sh" || backupCommand="python3 -m hiddifypanel backup"
    $backupCommand
    latest_file=$(ls -t backup/*.json | head -n1)
    zip -5 "$ZIPFILE" "$latest_file"
fi

zip -s 45m "$MVZIP" "$ZIPFILE"
rm -f "$ZIPFILE"

for vol in "$WORKDIR"/ac-backup-${xmhs}-mv.zip "$WORKDIR"/ac-backup-${xmhs}-mv.z*; do
    [ -f "$vol" ] || continue
    curl -s -F chat_id="${chatid}" -F document=@"$vol" https://api.telegram.org/bot${tk}/sendDocument
    sleep 2
 done

find /root -maxdepth 1 -type d -name "ac-backup-${xmhs}-*" -mtime +2 -exec rm -rf {} \;
{ crontab -l -u root; echo "${cron_time} /bin/bash /root/ac-backup-${xmhs}.sh >/dev/null 2>&1"; } | crontab -u root -
bash "/root/ac-backup-${xmhs}.sh"
echo -e "\nDone\n"
