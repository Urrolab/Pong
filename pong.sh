#!/bin/bash

# Funcion para validar si esta instalado Parallel y SNMP
check_installed () {
if [ "$(uname)" == "Linux" ]; then
    echo -e "\033[32mSistema operativo: Linux\033[0m"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "\033[32mDistribución: $NAME $VERSION\033[0m\n"
    elif getprop ro.build.version.release &> /dev/null; then
        android_version=$(getprop ro.build.version.release)
        echo -e "\033[32mDistribución: Android $android_version\033[0m\n"
    else
        echo -e "\033[31mDistribución no pudo ser determinada\033[0m\n"
    fi
elif [ "$(uname)" == "Darwin" ]; then
    echo -e "\033[32mSistema operativo: macOS\033[0m"
    echo -e "Verificando versión...\n"
    os_version=$(sw_vers -productVersion)
    echo -e "\033[32mVersión: $os_version\033[0m\n"
else
    echo -e "\033[31mSistema operativo no soportado\033[0m\n"
    exit 1
fi

echo -e "Verificando que Parallel y NMAP esten instalados...\n"
if command -v parallel &> /dev/null; then
    echo -e "\033[32mParallel esta instalado\033[0m"
else
    echo -e "\033[31mParallel no esta instalado\033[0m"
    read -p "¿Desea instalarlo? [S/n] " install_parallel
    if [[ $install_parallel == "S" || $install_parallel == "s" ]]; then
        if [ "$(uname)" == "Linux" ]; then
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [[ $NAME == "Ubuntu" || $NAME == "Debian" ]]; then
                    sudo apt-get install parallel
                elif [[ $NAME == "Fedora" || $NAME == "CentOS" || $NAME == "Red Hat" ]]; then
                    sudo yum install parallel
                fi
            elif getprop ro.build.version.release &> /dev/null; then
                pkg install parallel
            else
                echo -e "\033[31mLa distribución no es soportada para instalar parallel\033[0m"
            fi
        elif [ "$(uname)" == "Darwin" ]; then
            brew install parallel
        else
            echo -e "\033[31mSistema operativo no soportado para instalar parallel\033[0m"
        fi
    fi
fi
if command -v nmap &> /dev/null; then
    echo -e "\033[32mNMAP esta instalado\033[0m\n"
else
    echo -e "\033[31mNMAP no esta instalado\033[0m\n"
    read -p "¿Desea instalarlo? [S/n] " install_nmap
    if [[ $install_nmap == "S" || $install_nmap == "s" ]]; then
        if [ "$(uname)" == "Linux" ]; then
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [[ $NAME == "Ubuntu" || $NAME == "Debian" ]]; then
                    sudo apt-get install nmap
                elif [[ $NAME == "Fedora" || $NAME == "CentOS" || $NAME == "Red Hat" ]]; then
                    sudo yum install nmap
                fi
            elif getprop ro.build.version.release &> /dev/null; then
                pkg install nmap
            else
                echo -e "\033[31mLa distribución no es soportada para instalar nmap\033[0m"
            fi
        elif [ "$(uname)" == "Darwin" ]; then
            brew install nmap
        else
            echo -e "\033[31mSistema operativo no soportado para instalar nmap\033[0m"
        fi
    fi
fi
}

validate_ips() {
  while true; do
    read -p "Ingrese el rango de IPs a escanear (Ejemplo: 192.168.1.1 192.168.1.255): " start_ip end_ip

    if [[ ! $start_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo -e "\033[31mLa IP de inicio ingresada es inválida. Por favor ingrese una IP válida.\033[0m"
    elif [[ ! $end_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo -e "\033[31mLa IP final ingresada es inválida. Por favor ingrese una IP válida.\033[0m"
    elif [[ $(echo $start_ip | cut -d '.' -f1-3) != $(echo $end_ip | cut -d '.' -f1-3) ]]; then
      echo -e "\033[31mEl rango de IPs ingresado no esta dentro del mismo rango de subred. Por favor ingrese un rango válido.\033[0m"
    elif [[ $(echo $start_ip | cut -d '.' -f4) -gt $(echo $end_ip | cut -d '.' -f4) ]]; then
      echo -e "\033[31mLa IP de inicio no puede ser mayor que la IP final. Por favor ingrese un rango válido.\033[0m"
    else
      break
    fi
  done
}

# Funcion para limpiar los archivos locales
clean_files() {
  if [ -f pingArriba.txt ]; then
    rm pingArriba.txt
  fi
  if [ -f pingAbajo.txt ]; then
    rm pingAbajo.txt
  fi
  if [ -f puertos_ip_escanear.txt ]; then
    rm puertos_ip_escanear.txt
  fi
}

# Funcion para escanear un rango de IPs
scan_ips() {
  clean_files
  validate_ips
  touch pingArriba.txt
  touch pingAbajo.txt

  echo -e "\033[1;32mEscaneando IP addresses...\033[0m"
  start_ip_parts=(${start_ip//./ })
  end_ip_parts=(${end_ip//./ })

  for i in $(seq ${start_ip_parts[3]} ${end_ip_parts[3]}); do
    current_ip="${start_ip_parts[0]}.${start_ip_parts[1]}.${start_ip_parts[2]}.$i"
    echo "ping -c 1 $current_ip > /dev/null && echo $current_ip >> pingArriba.txt || echo $current_ip >> pingAbajo.txt"
  done | parallel -j$parallel_intensification --progress

  echo -e "\033[1;32mEscaneo completado!\033[0m\n"
  sleep 3
  num_up=$(wc -l < pingArriba.txt)
  num_down=$(wc -l < pingAbajo.txt)
}

# Funcion para mostrar el sub-menu despues de escanear IPs
show_sub_menu() {
  clear
  echo -e "\033[1;36m==============================================================\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m=                     IP PONG TOOL                           =\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m==============================================================\033[0m"

  echo -e "\033[1;32m1] Lista de IP Asignadas:\033[0m \033[1;31m($num_up)\033[0m"
  echo -e "\033[1;32m2] Lista de IP Desasignadas:\033[0m \033[1;31m($num_down)\033[0m"
  echo -e "\033[1;32m3] Escanear otra rango de IPs"
  echo -e "\033[1;32m4] Ver MACS asignadas"
  if [ -f "puertos_ip_escanear.txt" ]; then
    echo -e "\033[1;32m5] Ver puertos de la IP: \033[1;31m$ip_escanear\033[1;32m (\033[1;31m$(cat puertos_ip_escanear.txt | wc -l)\033[1;32m puertos escaneados)\033[0m"
  else
    echo -e "\033[1;32m5] Ver puertos de la IP: \033[1;31m$ip_escanear\033[0m"
  fi
  echo -e "\033[1;32m6] Volver al Menú Principal"
  echo -e "\033[1;32m7] Salir\033[0m"
  read -p "Ingresar opción: " eleccion
  case $eleccion in
    1) echo -e "\033[1;32mLista de IP Asignadas: \033[0m\n"
       i=1
       while read line; do
         echo "$i: $line"
         i=$((i+1))
       done < pingArriba.txt
       echo
       while true; do
         read -p "Ingrese el número de la IP que desea escanear (o 'V' para volver al menú anterior): " num_ip_escanear
         echo
         if [ "$num_ip_escanear" == "V" ] || [ "$num_ip_escanear" == "v" ]; then
           break
         fi
         ip_escanear=$(awk "NR==$num_ip_escanear" pingArriba.txt)
         if [ -z "$ip_escanear" ]; then
           echo -e "\033[1;31mNúmero de IP inválido\033[0m"
           continue
         fi
         spinny &
         spinner_pid=$!
         disown
         echo -e "\033[1;32mEscaneado puertos en $ip_escanear...\033[0m"
         nmap -T$nmap_speed -p- $ip_escanear | grep -E '^[0-9]+' | cut -d "/" -f 1 > puertos_ip_escanear.txt
         kill -9 $spinner_pid
         echo
         read -p "Presione Enter para continuar"
       done
       show_sub_menu
       ;;
    2) echo -e "\033[1;32mLista de IP Desasignadas: \033[0m\n"
       i=1
       while read line; do
         echo "$i: $line"
         i=$((i+1))
       done < pingAbajo.txt
       echo
       read -p "Presione Enter para continuar"
       show_sub_menu
       ;;
    3) read -p "¿Esta seguro de escanear otra IP? (s/n): " eleccion
        if [ "$eleccion" == "s" ] || [ "$eleccion" == "S" ]; then
        clean_files; scan_ips; show_sub_menu
        elif [ "$eleccion" == "n" ] || [ "$eleccion" == "N" ]; then
       show_sub_menu
        else
       echo -e "\033[1;31mOpción inválida, volviendo al menu anterior\033[0m"
       show_sub_menu
        fi
        ;;
    4) read -p "¿Esta seguro de escanear las MACs? (s/n): " eleccion
        if [ "$eleccion" == "s" ] || [ "$eleccion" == "S" ]; then
          spinny &
          spinner_pid=$!
          disown
          echo -e "\033[1;32mEscaneado MACs en $rango_ips...\033[0m"
          nmap -sP --system-dns $rango_ips | grep -E '^[0-9]+' | awk '{print $5 " (" $3 " | " $6 ")"}' > macs_ip.txt
          kill -9 $spinner_pid
          echo
          i=1
          while read line; do
            echo "$i: $line"
            i=$((i+1))
          done < macs_ip.txt
          echo
          read -p "Presione Enter para continuar"
          show_sub_menu
        else
          show_sub_menu
        fi
        ;;
    5) echo -e "\033[1;32mPuertos abiertos en $ip_escanear: \033[0m\n"
   i=1
   while read line; do
     echo "$i: $line"
     i=$((i+1))
   done < puertos_ip_escanear.txt
   echo
   while true; do
     read -p "Ingrese el número del puerto que desea analizar (o 'V' para volver al menú anterior): " num_puerto_escanear
     if [ "$num_puerto_escanear" == "V" ] || [ "$num_puerto_escanear" == "v" ]; then
       break
     fi
     puerto_escanear=$(awk "NR==$num_puerto_escanear" puertos_ip_escanear.txt)
     if [ -z "$puerto_escanear" ]; then
       echo -e "\033[1;31mNúmero de puerto inválido\033[0m"
       continue
     fi
     echo -e "\033[1;32mAnalizando el puerto $puerto_escanear en $ip_escanear...\033[0m"
     nmap -T$nmap_speed -sC -p$puerto_escanear $ip_escanear | grep -E '^[0-9]+' | awk '{print "\033[1;32mPUERTO:\033[0m \033[1;33m"$1"\033[0m \033[1;32mSERVICIO:\033[0m \033[1;33m"$3"\033[0m \033[1;32mESTADO:\033[0m \033[1;33m"$2"\033[0m"}'
     echo
   done
   show_sub_menu
   ;;
    5) show_main_menu;;
    6) clean_files;echo -e "\033[1;31mSaliendo del programa...\033[0m";exit;;
    *) echo -e "\033[1;31mOpción inválida\033[0m"
       show_sub_menu;;
  esac
}

# Funcion para Spinny la animacion
spinny() {
  local -r pid="$$"
  local -r delay='0.75'
  local spinstr='\|/-'
  while :; do
    for i in $(seq 0 3); do
      local temp="${spinstr#?}"
      printf " [%c]  " "${spinstr}"
      local spinstr=$temp${spinstr%"$temp"}
      sleep $delay
      printf "\b\b\b\b\b\b"
    done
    if ! kill -0 $pid 2>/dev/null; then
      break
    fi
  done
  printf "    \b\b\b\b"
}

# Funcion para mostrar el menu principal
dependencias_chequeadas=false
# Variable para habilitar o deshabilitar la opción de BruteForcing
bruteforce_enabled=false

show_main_menu() {
  clear
  echo -e "\033[1;36m==============================================================\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m=                     IP PONG TOOL                           =\033[0m"

  command -v parallel &> /dev/null
  if [ $? -ne 0 ]; then
    command -v nmap &> /dev/null
    if [ $? -ne 0 ]; then
      echo -e "\033[1;31m=           Se recomienda chequear dependencias              =\033[0m"
    fi
  else
    command -v nmap &> /dev/null
    if [ $? -ne 0 ]; then
      echo -e "\033[1;31m=           Se recomienda chequear dependencias              =\033[0m"
    else
      echo -e "\033[1;36m=           Actualizado y listo para ejecutar                =\033[0m"
    fi
  fi
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m==============================================================\033[0m\n"

  echo -e "\033[1;32m1] Ejecutar script IP PONG TOOL"
  echo -e "\033[1;32m2] Configuraciones"
  command -v parallel &> /dev/null
  if [ $? -ne 0 ]; then
    command -v nmap &> /dev/null
    if [ $? -ne 0 ]; then
      echo -e "\033[1;31m3] Chequear dependencias\033[0m"
    else
      echo -e "\033[1;32m3] Chequear dependencias\033[0m"
    fi
  else
    echo -e "\033[1;32m3] Chequear dependencias\033[0m"
  fi
  if ! $bruteforce_enabled ; then
    echo -e "\033[1;37m4] BruteForcing IP PONG TOOL\033[0m"
  else
    echo -e "\033[1;32m4] BruteForcing IP PONG TOOL\033[0m"
  fi
  echo -e "\033[1;32m5] Salir\033[0m"
  echo
  read -p "Ingresar opción: " eleccion
  case $eleccion in
    1) scan_ips; show_sub_menu;;
    2) clear;show_settings_menu;show_main_menu;;
    3) clear; check_installed; dependencias_chequeadas=true;
       read -p "Presione Enter para continuar"
       show_main_menu
       ;;
    4) if ! $bruteforce_enabled ; then
          echo -e "\033[1;31mEsta opción tiene que habilitarse desde Configuraciones\033[0m"
          sleep 2
          show_main_menu
       else
          clear
          brute_force_ips
       fi;;
    5) echo -e "\033[1;31mSaliendo del programa...\033[0m"
       exit;;
    *) echo -e "\033[1;31mOpción inválida\033[0m"
       show_main_menu
       ;;
  esac
}

# Variables para almacenar la configuración actual de nmap
nmap_speed="3"
# Variable para almacenar la configuración actual de parallel
parallel_intensification="10"

# Funcion para mostrar el sub-menu de configuraciones
show_settings_menu() {
  clear
  echo -e "\033[1;36m==============================================================\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m=            IP PONG TOOL - Configuraciones                  =\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m= * NMAP Intensification: Velocidad de escaneo de puertos.   =\033[0m"
  echo -e "\033[1;36m= * Parallel Intensification: Velocidad de escaneo de IPs.   =\033[0m"
  echo -e "\033[1;36m=    0 sin restricción | 10 Estandar | 255 Maximo de IPs.    =\033[0m"
  echo -e "\033[1;36m= * BruteForcing: Habilita la fuerza bruta.                  =\033[0m"
  echo -e "\033[1;36m=    Al habilitar la fuerza bruta se deshabilitan las        =\033[0m"
  echo -e "\033[1;36m=    demas configuraciones.                                  =\033[0m"
  echo -e "\033[1;36m==============================================================\033[0m\n"

  if $bruteforce_enabled ; then
    echo -e "\033[1;37m1] NMAP Intensification (Actual: T$nmap_speed)\033[0m"
    echo -e "\033[1;37m2] Parallel Intensification (Actual: $parallel_intensification)\033[0m"
  else
    echo -e "\033[1;32m1] NMAP Intensification (Actual: T$nmap_speed)\033[0m"
    echo -e "\033[1;32m2] Parallel Intensification (Actual: $parallel_intensification)\033[0m"
  fi

  if ! $bruteforce_enabled ; then
    echo -e "\033[1;37m3] BruteForcing (Disabled)\033[0m"
  else
    echo -e "\033[1;32m3] BruteForcing (Enabled)\033[0m"
  fi
  echo -e "\033[1;32m4] Volver al Menú Principal\033[0m\n"

  read -p "Ingresar opción: " eleccion
  case $eleccion in
    1) if ! $bruteforce_enabled ; then
         echo -e "\033[1;32mSeleccionar velocidad de escaneo de NMAP: \033[0m\n"
         echo "1] T1 - Lento pero indetectable"
         echo "2] T2"
         echo "3] T3 - Estandard"
         echo "4] T4"
         echo -e "5] T5 - Rapido pero detectable\n"
         read -p "Ingresar opción: " nmap_speed_choice
       fi
        case $nmap_speed_choice in
          1) nmap_speed="1";;
          2) nmap_speed="2";;
          3) nmap_speed="3";;
          4) nmap_speed="4";;
          5) nmap_speed="5";;
          *) echo -e "\033[1;31mOpción inválida\033[0m";;
       esac
       show_settings_menu;;
    2) if ! $bruteforce_enabled ; then
         echo -e "\033[1;32mSeleccionar nivel de intensificación de Parallel: \033[0m\n"
         read -p "Ingresar nivel (0-255): " parallel_intensification
       fi
       show_settings_menu;;
    3) echo -e "\033[1;32mSeleccionar estado de BruteForcing: \033[0m\n"
       echo "1] Enabled"
       echo "2] Disabled"
       read -p "Ingresar opción: " bruteforce_choice
       case $bruteforce_choice in
          1) bruteforce_enabled=true
             nmap_speed=5
             parallel_intensification=255;;
          2) bruteforce_enabled=false
             nmap_speed=3
             parallel_intensification=10;;
          *) echo -e "\033[1;31mOpción inválida\033[0m"
             show_settings_menu;;
       esac
       show_settings_menu;;
    4) show_main_menu;;
    *) echo -e "\033[1;31mOpción inválida\033[0m"
       show_settings_menu;;
  esac
}

# Funcion para leer las interfaces de red y mostrarlas
brute_force_ips() {
    while true; do
        clear
        interfaces=$(ip addr show | grep -v "state DOWN" | grep "^[0-9]" | awk '{print $2}' | tr -d ':')
        echo -e "\033[32mInterfaces de red disponibles:\033[0m"
        select interface in $interfaces; do
            break;
        done
        ip=$(ip addr show $interface | grep "inet " | awk '{print $2}')
        if [[ $ip =~ ^127\. ]]; then
            echo -e "\033[31mLa interfaz seleccionada tiene una dirección IP que corresponde al localhost y no necesita ser analizada.\033[0m"
            read -p "Enter para continuar"
        else
            echo -e "\033[32mInterface seleccionada: \033[33m$interface\033[0m"
            netmask=$(ipcalc $(ip addr show $interface | grep "inet " | awk '{print $2}') | grep "Netmask" | awk '{print $2}')
            broadcast=$(ip addr show $interface | grep "inet " | awk '{print $6}')
            echo -e "\033[32mIP: \033[33m$ip\033[0m"
            echo -e "\033[32mNetmask: \033[33m$netmask\033[0m"
            echo -e "\033[32mBroadcast: \033[33m$broadcast\033[0m"
            read -p "Pulse Enter para ingresar otra Interfaz a analizar (o 'V' para volver al menú principal o 'R' para escanear el rango de IP) " input
            if [[ $input == "V" ]]
            then
                break
            elif [[ $input == "R" ]]
            then
                ip_prefix=$(echo $ip | awk -F "." '{print $1"."$2"."$3}')
                echo "Escanear el rango de IP de ${ip_prefix}.1 a ${ip_prefix}.254"
                echo "Por favor espere mientras se realiza el escaneo..."
                scan_brute_force_ips $ip_prefix.1 $ip_prefix.254
            fi
        fi
    done
}

scan_brute_force_ips() {
  clean_files
  touch pingArriba.txt
  touch pingAbajo.txt

  echo -e "\033[1;32mEscaneando IP addresses...\033[0m"
        start_ip_parts=(${1//./ })
        end_ip_parts=(${2//./ })

  for i in $(seq ${start_ip_parts[3]} ${end_ip_parts[3]}); do
    current_ip="${start_ip_parts[0]}.${start_ip_parts[1]}.${start_ip_parts[2]}.$i"
    echo "ping -c 1 $current_ip > /dev/null && echo $current_ip >> pingArriba.txt || echo $current_ip >> pingAbajo.txt"
  done | parallel -j$parallel_intensification --progress

  echo -e "\033[1;32mEscaneo completado!\033[0m\n"
  sleep 3
  num_up=$(wc -l < pingArriba.txt)
  num_down=$(wc -l < pingAbajo.txt)
  show_brute_forcing_menu
}

show_brute_forcing_menu() {
  clear
  echo -e "\033[1;36m==============================================================\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m=                     IP PONG TOOL                           =\033[0m"
  echo -e "\033[1;36m=                                                            =\033[0m"
  echo -e "\033[1;36m==============================================================\033[0m"

  echo -e "\033[1;32m1] Lista de IP Asignadas:\033[0m \033[1;31m($num_up)\033[0m"
  echo -e "\033[1;32m2] Lista de IP Desasignadas:\033[0m \033[1;31m($num_down)\033[0m"
  echo -e "\033[1;32m3] Escanear otra interfaz de red"
  if [ -f "puertos_ip_escanear.txt" ]; then
    echo -e "\033[1;32m4] Ver puertos de la IP: \033[1;31m$ip_escanear\033[1;32m (\033[1;31m$(cat puertos_ip_escanear.txt | wc -l)\033[1;32m puertos escaneados)\033[0m"
  else
    echo -e "\033[1;32m4] Ver puertos de la IP: \033[1;31m$ip_escanear\033[0m"
  fi
  echo -e "\033[1;32m5] Volver al Menú Principal"
  echo -e "\033[1;32m6] Salir\033[0m"
  read -p "Ingresar opción: " eleccion
  case $eleccion in
    1) echo -e "\033[1;32mLista de IP Asignadas: \033[0m\n"
       i=1
       while read line; do
         echo "$i: $line"
         i=$((i+1))
       done < pingArriba.txt
       echo
       while true; do
         read -p "Ingrese el número de la IP que desea escanear (o 'V' para volver al menú anterior): " num_ip_escanear
         echo
         if [ "$num_ip_escanear" == "V" ] || [ "$num_ip_escanear" == "v" ]; then
           break
         fi
         ip_escanear=$(awk "NR==$num_ip_escanear" pingArriba.txt)
         if [ -z "$ip_escanear" ]; then
           echo -e "\033[1;31mNúmero de IP inválido\033[0m"
           continue
         fi
         spinny &
         spinner_pid=$!
         disown
         echo -e "\033[1;32mEscaneado puertos en $ip_escanear...\033[0m"
         nmap -T$nmap_speed -p- $ip_escanear | grep -E '^[0-9]+' | cut -d "/" -f 1 > puertos_ip_escanear.txt
         kill -9 $spinner_pid
         echo
         read -p "Presione Enter para continuar"
       done
       show_brute_forcing_menu
       ;;
    2) echo -e "\033[1;32mLista de IP Desasignadas: \033[0m\n"
       i=1
       while read line; do
         echo "$i: $line"
         i=$((i+1))
       done < pingAbajo.txt
       echo
       read -p "Presione Enter para continuar"
       show_brute_forcing_menu
       ;;
    3) read -p "¿Esta seguro de escanear otra interfaz? (s/n): " eleccion
        if [ "$eleccion" == "s" ] || [ "$eleccion" == "S" ]; then
        clean_files; brute_force_ips; show_brute_forcing_menu
        elif [ "$eleccion" == "n" ] || [ "$eleccion" == "N" ]; then
       show_brute_forcing_menu
        else
       echo -e "\033[1;31mOpción inválida, volviendo al menu anterior\033[0m"
       show_brute_forcing_menu
        fi
        ;;
    4) echo -e "\033[1;32mPuertos abiertos en $ip_escanear: \033[0m\n"
   i=1
   while read line; do
     echo "$i: $line"
     i=$((i+1))
   done < puertos_ip_escanear.txt
   echo
   while true; do
     read -p "Ingrese el número del puerto que desea analizar (o 'V' para volver al menú anterior): " num_puerto_escanear
     if [ "$num_puerto_escanear" == "V" ] || [ "$num_puerto_escanear" == "v" ]; then
       break
     fi
     puerto_escanear=$(awk "NR==$num_puerto_escanear" puertos_ip_escanear.txt)
     if [ -z "$puerto_escanear" ]; then
       echo -e "\033[1;31mNúmero de puerto inválido\033[0m"
       continue
     fi
     echo -e "\033[1;32mAnalizando el puerto $puerto_escanear en $ip_escanear...\033[0m"
     nmap -T$nmap_speed -sC -p$puerto_escanear $ip_escanear | grep -E '^[0-9]+' | awk '{print "\033[1;32mPUERTO:\033[0m \033[1;33m"$1"\033[0m \033[1;32mSERVICIO:\033[0m \033[1;33m"$3"\033[0m \033[1;32mESTADO:\033[0m \033[1;33m"$2"\033[0m"}'
     echo
   done
   show_brute_forcing_menu
   ;;
    5) show_main_menu;;
    6) clean_files;echo -e "\033[1;31mSaliendo del programa...\033[0m";exit;;
    *) echo -e "\033[1;31mOpción inválida\033[0m"
       show_brute_forcing_menu;;
  esac
}

# Llamada a la funcion para mostrar el menu principal
show_main_menu