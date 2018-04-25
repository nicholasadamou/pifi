#!/bin/bash

# Based on Adafruit Learning Technologies Onion Pi project
# see: http://learn.adafruit.com/onion-pi

declare BASH_UTILS_URL="https://raw.githubusercontent.com/nicholasadamou/bash-utils/master/utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

declare skipQuestions=false

trap "exit 1" TERM
export TOP_PID=$$

declare APP_NAME="Raspberry AnyFi"
declare MONIKER="4d4m0u"

declare STATION=wlan1
declare AP=wlan0
declare ETHER=eth0

# ----------------------------------------------------------------------
# | Helper Functions                                                   |
# ----------------------------------------------------------------------

wrong_key() {
  echo -e "$(tput setaf 6)\n-----------------------------$(tput sgr0)"
  echo -e "$(tput setaf 6)\nError: Wrong value.\n$(tput sgr0)"
  echo -e "$(tput setaf 6)-----------------------------\n$(tput sgr0)"
  echo -e "$(tput setaf 6)Enter any key to continue$(tput sgr0)"
  read -r key
}

set_ssid() {
  read -r -p "$(tput setaf 6)Specify \"SSID\": " -e SSID
}

set_passwd() {
  read -r -p "$(tput setaf 6)Specify \"WPA Passphrase\": " -e PASSWD
}

settings_show() {
  echo -e "$(tput setaf 6)\n--------------------------------------------------\n$(tput sgr0)"
  echo -e "$(tput setaf 6)You've specified following values:"
  echo -e "$(tput setaf 6)\n++++++++++++++++++++++++++++++++++++++++++++++++++\n$(tput sgr0)"
  echo -e "$(tput setaf 6)WiFi SSID:$(tput bold ; tput setaf 5) $SSID$(tput sgr0)$(tput setaf 6)"
  echo -e "$(tput setaf 6)WPA Passphrase:$(tput bold ; tput setaf 5) $PASSWD$(tput sgr0)$(tput setaf 6)"
  echo -e "$(tput setaf 6)\n++++++++++++++++++++++++++++++++++++++++++++++++++\n$(tput sgr0)"
}

settings_check() {
    settings_show
	default=Y
	read -r -p "$(tput setaf 6)Are these settings correct for $(tput bold ; tput setaf 5)$ssid$(tput sgr0)$(tput setaf 6) [Y/n] [Default=Y] [Quit=Q/q]?$(tput sgr0) " settings_confirm
	settings_confirm=${settings_confirm:-$default}
	case $settings_confirm in
		Y|y)
		;;
		N|n)
			echo -e "\n$(tput setaf 6)What would you like to edit?\n$(tput sgr0)"
			echo "$(tput setaf 6)[1] WiFi SSID$(tput sgr0)"
			echo "$(tput setaf 6)[2] WPA Passphrase$(tput sgr0)"

			read -r -p "$(tput setaf 6)Enter option number:$(tput sgr0) " settings_edit
			for letter in $settings_edit; do
					if [[ "$letter" == [1] ]];
					then
						set_ssid
						settings_show
					elif [[ "$letter" == [2] ]];
					then
						set_passwd
						settings_show
					else
						wrong_key
						settings_check
					fi
			done
		;;
		Q|q)
			exit 0
		;;
		*)
			wrong_key
			settings_check
		;;
	esac
}

setup_pifi() {
    echo -e "     
    $(tput setaf 6)   /         $(tput setaf 2)'. \ ' ' / .'$(tput setaf 6)         \\
    $(tput setaf 6)  |   /       $(tput setaf 1).~ .~~~..~.$(tput setaf 6)       \   |
    $(tput setaf 6) |   |   /  $(tput setaf 1) : .~.'~'.~. :$(tput setaf 6)   \   |   |
    $(tput setaf 6)|   |   |   $(tput setaf 1)~ (   ) (   ) ~$(tput setaf 6)   |   |   |
    $(tput setaf 6)|   |  |   $(tput setaf 1)( : '~'.~.'~' : )$(tput setaf 6)   |  |   |
    $(tput setaf 6)|   |   |   $(tput setaf 1)~ .~ (   ) ~. ~ $(tput setaf 6)  |   |   |
    $(tput setaf 6) |   |   \   $(tput setaf 1)(  : '~' :  )$(tput setaf 6)   /   |   |
    $(tput setaf 6)  |   \       $(tput setaf 1)'~ .~~~. ~'$(tput setaf 6)       /   |
    $(tput setaf 6)   \              $(tput setaf 1)'~'$(tput setaf 6)              /
    $(tput bold ; tput setaf 4)         "$AP"P_NAME$(tput sgr0)
    $(tput bold ; tput setaf 4)               by $(tput setaf 5)$MONIKER$(tput sgr0)
    "

    echo "$(tput setaf 6)This script will configure your Raspberry Pi as a wireless access point and to connect to any OPEN WiFi access point.$(tput sgr0)"
    read -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"

    update
    upgrade

    declare -a PKGS=(
        "hostapd"
        "isc-dhcp-server"
        "iptables-persistent"
    )

    for PKG in "${PKGS[@]}"; do
        install_package "$PKG" "$PKG"
    done

    x=/etc/dhcp/dhcpd.conf
    cp "$FILE" "$FILE".bak

    sed -i -e 's/option domain-name "example.org"/# option domain-name "example.org"/g' "$FILE"
    sed -i -e 's/option domain-name-servers ns1.example.org/# option domain-name-servers ns1.example.org/g' "$FILE"
    sed -i -e 's/#authoritative;/authoritative;/g' "$FILE"

    cat > "$FILE"<<- EOL
    subnet 192.168.42.0 netmask 255.255.255.0 {
    range 192.168.42.10 192.168.42.50;
    option broadcast-address 192.168.42.255;
    option routers 192.168.42.1;
    default-lease-time 600;
    max-lease-time 7200;
    option domain-name \042local\042;
    option domain-name-servers 1.1.1.1, 1.0.0.1; #Cloudflare DNS
    }
EOL

    FILE=/etc/default/isc-dhcp-server
    cp "$FILE" "$FILE".bak

    sed -i -e 's/INTERFACES=""/INTERFACES=""$AP""/g' "$FILE"

    FILE=/etc/network/interfaces

    ifdown "$AP"

    mv "$FILE" "$FILE".bak
    cat > "$FILE" <<- EOL
    auto lo

    iface lo inet loopback
    iface eth0 inet dhcp

    allow-hotplug "$AP"
    iface "$AP" inet static
    address 192.168.42.1
    netmask 255.255.255.0

    allow-hotplug "$STATION"
    iface "$STATION" inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOL

    ifconfig "$AP" 192.168.42.1

    FILE=/etc/hostapd/hostapd.conf

    if [ "$TRAVIS" != "true" ]; then
        print_question "Enter an SSID for the HostAPD Hotspot: "
        SSID="$(read -r)"

        PASSWD1="0"
        PASSWD2="1"
        until [ $PASSWD1 == $PASSWD2 ]; do
            print_question "Type a password to access your $SSID, then press [ENTER]: "
            read -s -r PASSWD1
            print_question "Verify password to access your $SSID, then press [ENTER]: "
            read -s -r PASSWD2
        done

        if [ "$PASSWD1" == "$PASSWD2" ]; then
            print_success "Password set. Edit $FILE to change."
        fi
    fi

    cat > "$FILE" <<- EOL
    interface="$AP"
    driver=rtl871xdrv
    ssid=$SSID
    hw_mode=g
    channel=6
    macaddr_acl=0
    auth_algs=1
    ignore_broadcast_ssid=0
    wpa=2
    wpa_passphrase=$PASSWD1
    wpa_key_mgmt=WPA2-PSK
    wpa_pairwise=TKIP
    rsn_pairwise=CCMP
EOL

    FILE=/etc/default/hostapd
    cp "$FILE" "$FILE".bak
    sed -i -e 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' "$FILE"

    FILE=/etc/sysctl.conf
    cp "$FILE" "$FILE".bak
    echo "net.ipv4.ip_forward=1" >> "$FILE"

    FILE=/etc/network/interfaces
    echo "up iptables-restore < /etc/iptables.ipv4.nat" >> "$FILE"

    sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

    iptables -t nat -A POSTROUTING -o "$STATION" -j MASQUERADE
    iptables -A FORWARD -i "$STATION" -o "$AP" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$AP" -o "$STATION" -j ACCEPT

    iptables -t nat -A POSTROUTING -o "$ETHER" -j MASQUERADE
    iptables -A FORWARD -i "$ETHER" -o "$AP" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$AP" -o "$ETHER" -j ACCEPT

    sh -c "iptables-save > /etc/iptables.ipv4.nat"
    sudo systemctl enable netfilter-persistent

    wget http://www.adafruit.com/downloads/adafruit_hostapd.zip

    unzip adafruit_hostapd.zip

    FILE=/usr/sbin/hostapd
    mv "$FILE" "$FILE".ORIG
    mv hostapd /usr/sbin
    chmod 755 /usr/sbin/hostapd

    rm adafruit_hostapd.zip

    service hostapd start
    service isc-dhcp-server start

    update-rc.d hostapd enable
    update-rc.d isc-dhcp-server enable

    set_ssid
	set_passwd
	settings_check
	configure_wifi

    FILE=/etc/wpa_supplicant/wpa_supplicant.conf

    cat > "$FILE" <<- EOL
    ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
    update_config=1

    network={
        ssid="$SSID"
        psk="$PASSWD"
    }
EOL

    sudo chmod 600 "$FILE"

    mv /usr/share/dbus-1/system-services/fi.epitest.hostap.WPASupplicant.service ~/
}

restart() {
    ask_for_confirmation "Do you want to restart?"
    
    if answer_is_yes; then
        sudo shutdown -r now &> /dev/null
    fi
}

main() {
    # Ensure that the following actions
    # are made relative to this file's path.

    cd "$(dirname "${BASH_SOURCE[0]}")" \
        && source <(curl -s "$BASH_UTILS_URL") \
        || exit 1

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    skip_questions "$@" \
        && skipQuestions=true

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    ask_for_sudo

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    setup_pifi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    
    if ! $skipQuestions; then
        restart
    fi
}

main "$@"