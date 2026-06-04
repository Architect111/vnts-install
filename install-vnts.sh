#!/bin/bash
BIN_REPO="https://github.com/Architect111/vnts-bin"
INSTALL_RAW="https://raw.githubusercontent.com/Architect111/vnts-install/main"
TAG_VER="v1.2.12"

get_arch_name(){
    local arch=$(uname -m)
    case ${arch} in
        x86_64)
            echo "vnts-x86_64-unknown-linux-musl-${TAG_VER}.tar.gz"
        ;;
        aarch64|arm64)
            echo "vnts-aarch64-unknown-linux-musl-${TAG_VER}.tar.gz"
        ;;
        armv7l)
            echo "vnts-armv7-unknown-linux-musleabihf-${TAG_VER}.tar.gz"
        ;;
        arm|armv5tel)
            echo "vnts-arm-unknown-linux-musleabi-${TAG_VER}.tar.gz"
        ;;
        *)
            echo ""
        ;;
    esac
}
BIN_NAME=$(get_arch_name)
if [ -z "${BIN_NAME}" ];then
    echo "不支持当前CPU架构：$(uname -m)"
    exit 1
fi

clean_env(){
    pkill -9 -f vnts 2>/dev/null
    sleep 1
}

Install(){
    cd /root
    clean_env
    wget -q ${BIN_REPO}/releases/download/${TAG_VER}/${BIN_NAME}
    tar -zxf ${BIN_NAME}
    chmod +x ./vnts
    wget -q ${INSTALL_RAW}/vnts.conf -O /root/vnts.conf
    wget -q ${INSTALL_RAW}/vnts-start.sh -O /root/vnts-start.sh
    chmod +x /root/vnts-start.sh

    mkdir -p /etc/systemd/system
    cat > /etc/systemd/system/vnts.service <<EOF
[Unit]
Description=VNTS Server
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/vnts-start.sh
ExecStop=/bin/pkill -9 -f vnts
ExecStopPost=/bin/sleep 1
Restart=on-failure
RestartSec=5
KillMode=control-group
KillSignal=SIGKILL
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now vnts
    ufw allow 29872/tcp
    ufw allow 29872/udp
    ufw allow 29870/tcp
    ufw reload
    echo "✅ VNTS安装完成，架构包：${BIN_NAME}"
}

Update(){
    cd /root
    clean_env
    rm -rf ./vnts ./${BIN_NAME}
    wget -q ${BIN_REPO}/releases/download/${TAG_VER}/${BIN_NAME}
    tar -zxf ${BIN_NAME}
    chmod +x ./vnts
    wget -q ${INSTALL_RAW}/vnts.conf -O /root/vnts.conf
    wget -q ${INSTALL_RAW}/vnts-start.sh -O /root/vnts-start.sh
    chmod +x /root/vnts-start.sh
    systemctl daemon-reload
    systemctl restart vnts
    echo "✅ VNTS更新完成"
}

Uninstall(){
    systemctl stop vnts
    systemctl disable vnts
    rm -f /etc/systemd/system/vnts.service
    systemctl daemon-reload
    rm -rf /root/vnts /root/vnts.conf /root/vnts-start.sh /root/${BIN_NAME}
    clean_env
    ufw delete allow 29872/tcp
    ufw delete allow 29872/udp
    ufw delete allow 29870/tcp
    ufw reload
    echo "✅ VNTS卸载完毕"
}

case "$1" in
install) Install ;;
update) Update ;;
uninstall) Uninstall ;;
*) echo "用法: $0 install | update | uninstall" ;;
esac
