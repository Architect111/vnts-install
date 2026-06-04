#!/bin/bash
BIN_REPO="https://github.com/Architect111/vnts-bin"
INSTALL_RAW="https://raw.githubusercontent.com/Architect111/vnts-install/main"
TAG_VER="v1.2.12"
LOCAL_CONF="/root/vnts.conf"

# 架构自动识别
get_arch_name(){
    local arch=$(uname -m)
    case ${arch} in
        x86_64) echo "vnts-x86_64-unknown-linux-musl-${TAG_VER}.tar.gz" ;;
        aarch64|arm64) echo "vnts-aarch64-unknown-linux-musl-${TAG_VER}.tar.gz" ;;
        armv7l) echo "vnts-armv7-unknown-linux-musleabihf-${TAG_VER}.tar.gz" ;;
        arm|armv5tel) echo "vnts-arm-unknown-linux-musleabi-${TAG_VER}.tar.gz" ;;
        *) echo "" ;;
    esac
}
BIN_NAME=$(get_arch_name)
if [ -z "${BIN_NAME}" ];then
    echo "不支持当前CPU架构：$(uname -m)"
    exit 1
fi

# 清理端口&进程
clean_env(){
    pkill -9 -f vnts 2>/dev/null
    sleep 1
}

# 交互式配置+默认值逻辑
SetConfig(){
    # 已有本地配置直接复用，不再弹窗
    if [ -f ${LOCAL_CONF} ];then
        echo "✅ 检测本地已有配置，沿用原有参数，跳过配置设置"
        return 0
    fi

    echo -e "\n========VNTS参数配置(直接回车使用默认值)========"
    read -p "服务监听端口【默认:29872】：" VNTS_PORT
    VNTS_PORT=${VNTS_PORT:-29872}

    read -p "连接密钥【回车自动随机生成密钥】：" VNTS_TOKEN
    # 空输入随机生成16位密钥
    VNTS_TOKEN=${VNTS_TOKEN:-$(head -c16 /dev/urandom|xxd -p)}

    read -p "WEB面板端口【默认:29870】：" WEB_PORT
    WEB_PORT=${WEB_PORT:-29870}

    read -p "WEB登录用户名【默认:admin】：" WEB_USERNAME
    WEB_USERNAME=${WEB_USERNAME:-admin}

    read -p "WEB登录密码【回车自动随机生成密码】：" WEB_PASSWORD
    # 空输入随机12位密码
    WEB_PASSWORD=${WEB_PASSWORD:-$(head -c12 /dev/urandom|xxd -p)}

    # 下载模板替换占位符生成私有配置
    wget -q ${INSTALL_RAW}/vnts.conf -O ${LOCAL_CONF}.tmp
    sed -i \
    -e "s|__VNTS_PORT__|${VNTS_PORT}|g" \
    -e "s|__VNTS_TOKEN__|${VNTS_TOKEN}|g" \
    -e "s|__WEB_PORT__|${WEB_PORT}|g" \
    -e "s|__WEB_USERNAME__|${WEB_USERNAME}|g" \
    -e "s|__WEB_PASSWORD__|${WEB_PASSWORD}|g" ${LOCAL_CONF}.tmp
    mv ${LOCAL_CONF}.tmp ${LOCAL_CONF}

    echo -e "\n✅ 配置生成完毕，配置文件：${LOCAL_CONF}"
    echo "📌 WEB账号:${WEB_USERNAME} | 密码:${WEB_PASSWORD}，妥善保存！"
}

# 安装逻辑
Install(){
    cd /root
    clean_env
    # 拉取对应架构二进制
    wget -q ${BIN_REPO}/releases/download/${TAG_VER}/${BIN_NAME}
    tar -zxf ${BIN_NAME}
    chmod +x ./vnts
    # 生成本地配置
    SetConfig
    # 只拉启动脚本，不拉配置
    wget -q ${INSTALL_RAW}/vnts-start.sh -O /root/vnts-start.sh
    chmod +x /root/vnts-start.sh

    # 写入systemd服务
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

    # 自动放行配置内端口
    PORT_MAIN=$(grep PORT= ${LOCAL_CONF}|cut -d'=' -f2)
    PORT_WEB=$(grep WEB_PORT= ${LOCAL_CONF}|cut -d'=' -f2)
    ufw allow ${PORT_MAIN}/tcp
    ufw allow ${PORT_MAIN}/udp
    ufw allow ${PORT_WEB}/tcp
    ufw reload

    echo -e "\n✅ VNTS安装完成！查看状态：systemctl status vnts"
}

# 更新：只更程序+启动脚本，**绝不覆盖本地配置文件**
Update(){
    cd /root
    clean_env
    rm -rf ./vnts ./${BIN_NAME}
    wget -q ${BIN_REPO}/releases/download/${TAG_VER}/${BIN_NAME}
    tar -zxf ${BIN_NAME}
    chmod +x ./vnts
    # 更新启动脚本
    wget -q ${INSTALL_RAW}/vnts-start.sh -O /root/vnts-start.sh
    chmod +x /root/vnts-start.sh

    systemctl daemon-reload
    systemctl restart vnts
    echo "✅ 更新完成，本机原有密码、端口全部保留未修改"
}

# 卸载
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
    echo "✅ VNTS已彻底卸载"
}

case "$1" in
install) Install ;;
update) Update ;;
uninstall) Uninstall ;;
*) echo "使用命令：$0 install | update | uninstall" ;;
esac
