#!/bin/sh

. /usr/share/libubox/jshn.sh

NAME=$1
ADDRESS=$2
PRIVATE_KEY=$3
DNS=$4

echo >/tmp/mullvad.uci.batch

random()
{
	local min=$1
	local max=$(($2-${min}+1))
	local num=$(date +%s%N)
	echo "$((${num}%${max}+${min}))"
}

port_start=19000
peer_id=$(random 1 10000)

random_port()
{
	local port=$(random 1 65535)
	local port_flag=1

	while [ "${port_flag}" = "1" ]
	do
		local tcp_listen_num=`netstat -an | grep ":${port} " | awk '$1 == "tcp" && $NF == "LISTEN" {print $0}' | wc -l`
		local udp_listen_num=`netstat -an | grep ":${port} " | awk '$1 == "udp" && $NF == "0.0.0.0:*" {print $0}' | wc -l`
		local listen_num=$((${tcp_listen_num}+${udp_listen_num}))

		if [ "${listen_num}" = "0" ]; then
			port_flag=0
		else
			port=$(random 1 65535)
		fi
	done

	echo "${port}"
}

set_config()
{
	local hostname=$1
	local ipv4_addr_in=$2
	local public_key=$3
	local multihop_port=$4
	local end_point=${ipv4_addr_in}:${multihop_port}
	local hostcode=${hostname}
	peer_id=$(($peer_id+1))
	local peer_name=${NAME}_${hostcode}
	local flag=1

	while [ "${flag}" = "1" ]
	do
		if [ -z "$(uci -q get wireguard.wg_peer_${peer_id})" ]; then
echo "config peers wg_peer_${peer_id}
	option name '"${peer_name}"'
	option address '"${ADDRESS}"'
	option listen_port '$port_start'
	option private_key '"${PRIVATE_KEY}"'
	option dns '"${DNS}"'
	option end_point '"${end_point}"'
	option public_key '"${public_key}"'
	option allowed_ips '"0.0.0.0/0,::/0"'
	option persistent_keepalive '"25"'
	option mtu '"1380"'
" >>/tmp/mullvad.uci.batch

			port_start=$(($port_start+1))
#			uci commit wireguard
			flag=0
		else
			peer_id=$(($peer_id+1))
		fi
	done
}

json_init
json_load_file /tmp/mullvad

json_get_keys country_keys countries
json_select countries

for country_key in ${country_keys}; do
	json_select ${country_key}
	json_get_vars name code
	json_get_keys city_keys cities
	json_select cities
	for city_key in ${city_keys}; do
		json_select ${city_key}
		json_get_vars name code
		json_get_keys relay_keys relays
		json_select relays
		for relay_key in ${relay_keys}; do
			json_select ${relay_key}
			json_get_vars hostname ipv4_addr_in public_key multihop_port
			set_config ${hostname} ${ipv4_addr_in} ${public_key} ${multihop_port}
			json_select ..
		done
		json_select ..
		json_select ..
	done
	json_select ..
	json_select ..
done
uci -q batch <<EOF
$(cat /tmp/mullvad.uci.batch)
EOF
uci commit wireguard
rm -rf /tmp/mullvad
cat /tmp/mullvad.uci.batch >>/etc/config/wireguard
rm -f /tmp/mullvad.uci.batch

exit 0
