#!/bin/bash
BOT_BASE_PATH="/opt/deliver_bot"
BOT_GIT_URL="https://github.com/tech-fever/deliver_bot.git"
BOT_RAW_URL="https://raw.githubusercontent.com/tech-fever/deliver_bot/main/"


red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
export PATH=$PATH:/usr/local/bin


pre_check() {
    command -v systemctl >/dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "不支持此系统：未找到 systemctl 命令"
        exit 1
    fi

    # check root
    [[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

}

install_base() {
    (command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1 && command -v getenforce >/dev/null 2>&1) ||
        (install_soft curl wget git unzip python3-pip)
}

selinux(){
    #判断当前的状态
    getenforce | grep '[Ee]nfor'
    if [ $? -eq 0 ];then
        echo -e "SELinux是开启状态，正在关闭！" 
        setenforce 0 &>/dev/null
        find_key="SELINUX="
        sed -ri "/^$find_key/c${find_key}disabled" /etc/selinux/config
    fi
}

install() {
    install_base
    selinux

    echo -e "> 安装Deliver Bot"

    mkdir -p $BOT_BASE_PATH/data && cd $BOT_BASE_PATH
    chmod 777 -R $BOT_BASE_PATH

    echo -e "正在下载"
    git clone $BOT_GIT_URL ./
    if [[ $? != 0 ]]; then
        echo -e "${red}下载失败，请检查本机能否连接 GITHUB${plain}"
        return 0
    fi

    echo -e "修改配置"
    modify_config

    echo -e "正在安装"
    cd $BOT_BASE_PATH && pip install -r requirements.txt
    if [[ $? != 0 ]]; then
        echo -e "${red}python依赖安装失败，请使用 pip install -r requirements.txt 手动安装${plain}"
        return 0
    fi
    wget -O /etc/systemd/system/bot.service $BOT_RAW_URL/bot.service
    systemctl daemon-reload
    systemctl enable bot.service
    systemctl start bot.service
    echo -e "> 安装完成"
}


uninstall() {
    echo -e "> 卸载Deliver Bot"
    systemctl stop bot.service
    systemctl disable bot.service
    rm -rf $BOT_BASE_PATH
    echo -e "> 卸载完成"
}


restart() {
    systemctl restart bot.service
}


status() {
    systemctl status bot.service
}


modify_config() {
    echo -e "> 修改配置"
    cd $BOT_BASE_PATH
    wget -O $BOT_BASE_PATH/config.ini $BOT_RAW_URL/config.ini.example

    read -ep "请输入你的bot token: " bot_token
    read -ep "请输入你的telegram id: " ownner_id
    sed -i "s/^token.*$/token = $bot_token/g" $BOT_BASE_PATH/config.ini
    sed -i "s/^owner_id.*$/owner_id = $ownner_id/g" $BOT_BASE_PATH/config.ini
}

show_menu() {
    echo -e "
    ${green}bot管理脚本${plain} ${red}${NZ_VERSION}${plain}
    --- https://github.com/tech-fever/deliver_bot ---
    ${green}1.${plain}  安装
    ${green}2.${plain}  卸载
    ${green}3.${plain}  重启
    ${green}4.${plain}  修改配置
    ${green}5.${plain}  查看状态
    ————————————————-
    ${green}0.${plain}  退出脚本
    "
    echo && read -ep "请输入选择 [0-13]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install
        ;;
    2)
        uninstall
        ;;
    3)
        restart
        ;;
    4)
        modify_config
        ;;
    5)
        status
        ;;
    *)
        echo -e "${red}请输入正确的数字 [0-13]${plain}"
        ;;
    esac
}

pre_check
show_menu
