#!/bin/bash
tput setaf 7 ; tput setab 6 ; tput bold ; printf '%35s%s%-20s\n' "Configuracao Inicial do VPS Mining" ; tput sgr0
tput setaf 3 ; tput bold ; echo "" ; echo "Este script ira compilar o xmr-stak-cpu, fazer configuracoes no sysctl.conf e" ; tput sgr0
tput setaf 3 ; tput bold ; echo "/etc/security/limits.conf e instalar alguns pacotes uteis." ; echo "" ; tput sgr0
tput setaf 3 ; tput bold ; echo -e "A instalação iniciará em 3 segundos\n\n" ; tput sgr0 ; sleep 3

#XMR-Stak-CPU compiling
cd ~
if ! hash nodejs 2>/dev/null; then
	curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash && \
	sudo npm -g install pm2 && wget https://github.com/minerdude/caverna/raw/master/stak.json
fi
sudo apt update && sudo apt install build-essential cmake libssl-dev libhwloc-dev nano git htop screen nodejs -y && \
sudo sed -i 's/#startup_message.*/startup_message off/' /etc/screenrc
sudo sed -i 's/.*\${distro_id}:\${distro_codename}-updates.*/\t"\${distro_id}:\${distro_codename}-updates";/' /etc/apt/apt.conf.d/50unattended-upgrades
if [ -d xmr-stak ]; then
	echo -e "\nDiretório xmr-stak ja existe."
else
	git clone -b dev https://github.com/fireice-uk/xmr-stak && cd xmr-stak
fi
sed -i 's/constexpr double fDevDonationLevel.*/constexpr double fDevDonationLevel = 0.0;/' xmrstak/donate-level.hpp
cmake . -DMICROHTTPD_ENABLE=OFF -DXMR-STAK_CURRENCY=monero -DCPU_ENABLE=ON -DOpenCL_ENABLE=OFF -DCUDA_ENABLE=OFF && \
make -j $(nproc) install
if [ $? != 0 ]; then
	echo -e "\nErro ao compilar! \nError exit code: $?" >&2
	exit 1
else
	echo -e "\nXMR-Stak Compilado!\n"
fi
cp bin/xmr-stak ~/xmrstak
sleep 1

echo -e "Agora as configuracoes finais.\n"
sleep 1

#Aliases
cd ~
if grep -q "#alias-xmr" .bash_aliases; then
	echo -e "\nAliases ja configurado."
else
	echo -e "#alias-xmr\nalias update='sudo apt update'\nalias upgrade='sudo apt upgrade'\nalias clean='sudo apt clean && sudo apt autoclean && sudo apt autoremove'\nalias upgradable='apt list --upgradable'\nalias xmrstart='pm2 start stak.json'\nalias xmrstop='pm2 stop stak'" | tee -a ~/.bash_aliases
	source .bashrc
fi
#Sysctl Conf
if [  -f "/etc/sysctl.d/99-xmrmining.conf" ]; then
	echo -e "\nSysconf já configurado anteriormente."
else
	echo -e "\n#Protect Against TCP Time-Wait\nnet.ipv4.tcp_rfc1337 = 1\n" | sudo tee /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Latency\nnet.ipv4.tcp_low_latency = 1\nnet.ipv4.tcp_slow_start_after_idle = 0\n" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Hugepages\nvm.nr_hugepages = 128\n" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Do less swapping\nvm.swappiness = 10\nvm.dirty_ratio = 10\nvm.dirty_background_ratio = 5\nvm.vfs_cache_pressure = 50\n" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Disable on all interfaces\nnet.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	sudo sysctl -p /etc/sysctl.d/99-xmrmining.conf
fi

#Limits.conf
if grep -q "#Limits" /etc/security/limits.conf; then
	echo -e "\nLimits ja configurado anteriormente."
else
	echo -e "\n#Limits para mining\n* soft memlock 262144\n* hard memlock 262144" | sudo tee -a /etc/security/limits.conf
fi

echo -e "\nFinalizado!\n"
echo "Agora voce precisa ajustar as configuracoes do xmr-stak."
./xmrstak
echo -e "\nAte mais!\n"
exit 0