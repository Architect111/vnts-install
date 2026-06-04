#!/bin/bash
BIN_REPO="https://github.com/Architect111/vnts-bin"
INSTALL_RAW="https://raw.githubusercontent.com/Architect111/vnts-install/main"
TAG_VER="v1.2.12"
LOCAL_CONF="/root/vnts.conf"

# 自动识别CPU架构
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

# 清理进程+占用端口
clean_env(){
    pkill -9 -f vnts 2>/dev/null
    sleep 1
}

# 交互式配置，回车默认值，空密钥/密码自动随机生成
SetConfig(){
    if [ -f ${LOCAL_CONF} ];then
        echo "✅ 检测本地已有私有配置，沿用原有参数，跳过配置填写"
        return 0
    fi

    echo -e "\n========VNTS参数配置(直接回车使用默认值)========"
    read -p "服务监听端口【默认:29872】：" VNTS_PORT
    VNTS_PORT=${VNTS_PORT:-29872}

    read -p "连接密钥【回车自动随机生成密钥】：" VNTS_TOKEN
    VNTS_TOKEN=${VNTS_TOKEN:-$(head -c16 /dev/urandom|xxd -p)}

    read -p "WEB面板端口【默认:29870】：" WEB_PORT
    WEB_PORT=${WEB_PORT:-29870}

    read -p "WEB登录用户名【默认:admin】：" WEB_USERNAME
    WEB_USERNAME=${WEB_USERNAME:-admin}

    read -p "WEB登录密码【回车自动随机生成密码】：" WEB_PASSWORD
    WEB_PASSWORD=${WEB_PASSWORD:-$(head -c12 /dev/urandom|xxd -p)}

    # 拉取云端模板，替换占位符生成本地私有配置
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

# 安装功能
Install(){
    cd /root
    clean_env
    wget -q ${BIN_REPO}/releases/download/${TAG_VER}/${BIN_NAME}
    tar -zxf ${BIN_NAME}
    chmod +x ./vnts
    SetConfig
    wget -q ${INSTALL_RAW}/vnts-start.sh -O /root/vnts-start.sh
    chmod +x /root/vnts-start.sh

    # 写入systemd服务配置
    mkdir -p /etc/systemd/system
    cat > /etc/systemd/system/vnts.service <<EOF
[Unit]
Description=VNTS内网穿透服务
After=network.target
Documentation=https://github.com/Architect111/vnts-install
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

    # 自动放行配置里的端口
    PORT_MAIN=$(grep PORT= ${LOCAL_CONF}|cut -d'=' -f2)
    PORT_WEB=$(grep WEB_PORT= ${LOCAL_CONF}|cut -d'=' -f2)
    ufw allow ${PORT_MAIN}/tcp
    ufw allow ${PORT_MAIN}/udp
    ufw allow ${PORT_WEB}/tcp
    ufw reload

    echo -e "\n✅ VNTS安装完成！查看运行状态：systemctl status vnts"
}

# 更新功能：仅更新程序与启动脚本，永久保留本地配置不覆盖
Update(){
    cd /root
    clean_env
    rm -rf ./vnts ./${BIN_NAME}
    wget -q ${BIN_REPO}/releases/download/${TAG_VER}/${BIN_NAME}
    tar -zxf ${BIN_NAME}
    chmod +x ./vnts
    wget -q ${INSTALL_RAW}/vnts-start.sh -O /root/vnts-start.sh
    chmod +x /root/vnts-start.sh

    systemctl daemon-reload
    systemctl restart vnts
    echo "✅ 更新完成，本机原有密码、端口全部保留未修改"
}

# 完整卸载
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
    echo "✅ VNTS已彻底卸载完毕"
}

# 命令分支 + 内置说明书（对标你截图FRPS格式）
case "$1" in
install) Install ;;
update) Update ;;
uninstall) Uninstall ;;
config)
    echo "📝 正在打开本地私有配置文件：${LOCAL_CONF}"
    nano ${LOCAL_CONF}
    echo "💡 修改完成后执行：systemctl restart vnts 即可生效"
;;
version)
    echo "当前VNTS程序版本：${TAG_VER}"
;;
*)
# 下面就是和你截图一模一样的说明书，不输参数/输错命令自动弹出
echo "===================== VNTS 使用帮助 ====================="
echo "Uninstall（卸载）"
echo "  ./install-vnts.sh uninstall"
echo ""
echo "Update（更新程序/启动脚本，保留本机配置）"
echo "  ./install-vnts.sh update"
echo ""
echo "Server management（服务管理器）"
echo "  Usage: ./install-vnts.sh {install|update|uninstall|config|version}"
echo ""
echo "参数说明："
echo "  install    → 全新安装VNTS服务"
echo "  update     → 在线升级程序，不改动本地配置密码"
echo "  uninstall  → 完整删除程序、配置、系统服务"
echo "  config     → 一键编辑本地配置文件(修改端口/密钥/面板密码)"
echo "  version    → 查看当前VNTS版本号"
echo ""
echo "【系统原生启停命令】"
echo "systemctl {start|stop|restart|status} vnts"
echo "========================================================"
;;
esac
