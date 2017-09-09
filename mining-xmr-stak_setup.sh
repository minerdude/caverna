#!/bin/bash

#Configuração inicial
function inicialconf ()
{
local resposta="s"
echo -e "Instalacao de pacotes necessarios...\n"
sleep 1
sudo apt update && sudo apt install unattended-upgrades nano git htop screen build-essential cmake libssl-dev libhwloc-dev -y
sudo sed -i 's/#startup_message.*/startup_message off/' /etc/screenrc
sudo sed -i 's/.*\${distro_id}:\${distro_codename}-updates.*/\t"\${distro_id}:\${distro_codename}-updates";/' /etc/apt/apt.conf.d/50unattended-upgrades
# read USERNAME -p "Informe nome do usuário a criar: "
# read PASSWORD -p "Informe a senha: "
# adduser --quiet --disabled-password --gecos "User" "$USERNAME" && \
# echo "$password" | sudo chpasswd <<< "$USERNAME":"$PASSWORD" && \ 
# usermod -aG sudo "$username"
# sudo sed -i 's/%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/' /etc/sudoers
# sudo sed -i 's/*.Port 22/Port 4443/' /etc/ssh/sshd_config
# sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
echo -e "alias update='sudo apt update'\nalias upgrade='sudo apt upgrade'\nalias clean='sudo apt clean && sudo apt autoclean && sudo apt autoremove'\nalias xmr='./xmr-stak config.txt'\nalias upgradable='apt list --upgradable'" | tee -a ~/.bash_aliases
source .bashrc
# sudo service ssh restart
return $?
}

#XMR-Stak-CPU compiling
function stakmake ()
{
git clone -b dev git://github.com/fireice-uk/xmr-stak-cpu.git && \
cd xmr-stak-cpu
sed -i 's/constexpr double fDevDonationLevel.*/constexpr double fDevDonationLevel = 0.0;/' donate-level.h
cmake .  -DMICROHTTPD_ENABLE=OFF  && \
make -j $(nproc)
if [ "$?" -eq "0" ]; then
	cp bin/xmr-stak-cpu ~/xmr-stak
	cp config.txt ~/config.txt
	# echo "Configuracao do config.txt do Stak..."
	# read -p "Informe quantos cores deseja utilizar: " ncores
	# sed '/"low_power_mode"/d' ~/config.txt > /tmp/config && mv /tmp/config ~/config.txt
	return $?
else
	return 1
fi
}

#Sysctl Conf
function confsysctl ()
{
if [  -f "/etc/sysctl.d/99-xmrmining.conf" ]; then
	echo -e "\nSysconf já configurado anteriormente.\n"
	return 11
else
	echo -e "\n#Protect Against TCP Time-Wait\nnet.ipv4.tcp_rfc1337 = 1\n" | sudo tee /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Latency\nnet.ipv4.tcp_low_latency = 1\nnet.ipv4.tcp_slow_start_after_idle = 0\n" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Hugepages\nvm.nr_hugepages = 128\n" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Do less swapping\nvm.swappiness = 10\nvm.dirty_ratio = 10\nvm.dirty_background_ratio = 5\nvm.vfs_cache_pressure = 50\n" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	echo -e "#Disable on all interfaces\nnet.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.d/99-xmrmining.conf
	sudo sysctl -p /etc/sysctl.d/99-xmrmining.conf
	return $?
fi
}

#Limits.conf
function limitsconf ()
{
if grep -q "#Limits" /etc/security/limits.conf; then
	echo -e "\nLimits ja configurado anteriormente.\n"
	return 12
else
	echo -e "\n#Limits para mining\n* soft memlock 262144\n* hard memlock 262144" | sudo tee -a /etc/security/limits.conf
	return $?
fi
}

tput setaf 7 ; tput setab 6 ; tput bold ; printf '%35s%s%-20s\n' "Configuracao Inicial do VPS Mining\n" ; tput sgr0
tput setaf 3 ; tput bold ; echo -e "Este script ira compilar o xmr-stak-cpu, fazer configuracoes no sysctl.conf e\n" ; tput sgr0
tput setaf 3 ; tput bold ; echo -e "/etc/security/limits.conf e instalar alguns pacotes uteis.\n" ; tput sgr0
tput setaf 3 ; tput bold ; echo -e "A instalacao iniciara em 3 segundos\n\n" ; tput sgr0 ; sleep 3

#Configuração inicial
inicialconf

#Compilacao do Stak
stakmake
retorno = $?
if [ "$retorno" = "0" ]; then
	echo -e "\n\nXMR-Stak-CPU Compilado!"
	sleep 1
else
	echo -e "\n\nErro ao compilar! Saindo..."
	exit 1
fi
echo -e "\n\nAgora as configuracoes finais."
#Sysctl
confsysctl
retorno = $?
if [ "$retorno" = "0" ]; then
	echo -e "\nSysctl configurado!"
	sleep 1
else
	echo -e "\nErro ao configurar Sysctl.conf. Saindo..."
	exit 1
fi

#Limits
limitsconf
retorno = $?
if [ "$retorno" = "0" ]; then
	echo -e "\nLimits.conf configurado!"
	sleep 1
else
	echo -e "\nErro ao configurar Limits.conf. Saindo..."
	exit 1
fi

echo -e "\nFinalizado!"
echo -e "\nAgora voce precisa ajustar as configuracoes do config.txt do xmr-stak."
echo -e "\nAntes, reinicie a VPS para que as configuracoes facam efeito!\n"
echo -e "\nAte mais!\n"