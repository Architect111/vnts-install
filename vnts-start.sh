#!/bin/bash
source /root/vnts.conf
MAIN_PORT=29872
pkill -9 -f vnts 2>/dev/null
sleep 0.8
clear_single_port(){
local port=$1
PID=$(ss -ltnp 2>/dev/null | grep ":$port" | sed -r 's/.*pid=([0-9]+).*/\1/')
[ -n "$PID" ] && kill -9 $PID 2>/dev/null && echo "清理端口${port}占用PID:${PID}"
}
clear_single_port $MAIN_PORT
sleep 2
CMD="/root/vnts"
[ -n "$PORT" ] && CMD+=" -p $PORT"
[ -n "$WHITE_TOKEN" ] && CMD+=" -w $WHITE_TOKEN"
[ -n "$WEB_PORT" ] && CMD+=" -P $WEB_PORT"
[ -n "$WEB_USER" ] && CMD+=" -U $WEB_USER"
[ -n "$WEB_PASS" ] && CMD+=" -W $WEB_PASS"
[ -n "$GATEWAY" ] && CMD+=" -g $GATEWAY"
[ -n "$NETMASK" ] && CMD+=" -m $NETMASK"
[ -n "$LOG_PATH" ] && CMD+=" -l $LOG_PATH"
exec $CMD
