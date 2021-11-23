#!/bin/bash
# Projet Linux pour l'embarqué
# PAEZ Edward © Instrumentation Dec 2020

#sudo apt-get install bc #Pour travailler avec float, à install une seule fois!!!!!!

#═══════════════════════════════════════════
###JUSTE LA PRIMIERE FOIS AVEC VOTRE RASPBERRY
#Pour exporter le pin vers l'espace utilisateur
#echo "17" > /sys/class/gpio/export
#Pour définir la broche 17 comme sortie
#echo "out" > /sys/class/gpio/gpio17/direction
#═══════════════════════════════════════════

#Définition de variables
#═══════════════════════════════════════════
myip=$(hostname -I)                #IP address
myip=$(echo "${myip:0:15}")        # Pour limiter les caractères de 0 à 15
myip_p="$(wget -qO- ipinfo.io/ip)" # IP publique

#La température du processeur est stocké dans le fichier /sys/class/thermal/thermal_zone0/temp, exprimée en millième de °C
TempCPU=$(cat /sys/class/thermal/thermal_zone0/temp)
TempCPU=$(echo "$TempCPU/1000" | bc -l)
TempCPU=$(echo "${TempCPU:0:6}") # Pour limiter les caractères de 0 à 6

#La température de la GPU est accessible depuis la commande vcgencmd et le paramètre measure_temp
TempGPU=$(vcgencmd measure_temp)   #Shows core temperature of BCM2835 SoC.
TempGPU=$(echo "${TempGPU#temp=}") #Pour la suppression du motif correspondant au préfixe
#Shows voltage, id can be one core, sdram_c, sdram_i, sdram_p, and defaults to core if not specified
VoltCPU=$(vcgencmd measure_volts core)
VoltCPU=$(echo "${VoltCPU#volt=}") #Pour la suppression du motif correspondant au préfixe

myHost=$(hostname) # Pour avoir my Hostname variable
UtcNow=$(date -u)  # Pour avoir le temps en UTC

tempDS18B20=$(find /sys/bus/w1/devices/ -name "28-*" -exec cat {}/w1_slave \; | grep "t=" | awk -F "t=" '{print $2/1000}')

EtatPin_17=$(cat /sys/class/gpio/gpio17/value)
# si EtatPin_17=1, Relay OFF
# si EtatPin_17=0, Relay ON

if [ $EtatPin_17 -eq 0 ]; then
    Etat_Relay=$(echo "Relay ON")
else
    Etat_Relay=$(echo "Relay OFF")
fi

#═══════════════════════════════════════════

function actualiser_variables() {
    myip=$(hostname -I)                #IP address
    myip=$(echo "${myip:0:15}")        #Pour limiter le mot à 15 caractères
    myip_p="$(wget -qO- ipinfo.io/ip)" # IP publique

    #La température du processeur est stocké dans le fichier /sys/class/thermal/thermal_zone0/temp, exprimée en millième de °C
    TempCPU=$(cat /sys/class/thermal/thermal_zone0/temp)
    TempCPU=$(echo "$TempCPU/1000" | bc -l) #Pour avoir les décimaux
    TempCPU=$(echo "${TempCPU:0:6}")        #Pour limiter le mot à 6 caractères

    #La température de la GPU est accessible depuis la commande vcgencmd et le paramètre measure_temp
    TempGPU=$(vcgencmd measure_temp)   #Shows core temperature of BCM2835 SoC.
    TempGPU=$(echo "${TempGPU#temp=}") #Pour la suppression du motif correspondant au préfixe
    #Shows voltage, id can be one core, sdram_c, sdram_i, sdram_p, and defaults to core if not specified
    VoltCPU=$(vcgencmd measure_volts core)
    VoltCPU=$(echo "${VoltCPU#volt=}") #Pour la suppression du motif correspondant au préfixe

    myHost=$(hostname) # Pour avoir my Hostname variable
    UtcNow=$(date -u)  # Pour avoir le temps en UTC

    tempDS18B20=$(find /sys/bus/w1/devices/ -name "28-*" -exec cat {}/w1_slave \; | grep "t=" | awk -F "t=" '{print $2/1000}')

    EtatPin_17=$(cat /sys/class/gpio/gpio17/value)
    # si EtatPin_17=1, Relay OFF
    # si EtatPin_17=0, Relay ON
    if [ $EtatPin_17 -eq 0 ]; then
        Etat_Relay=$(echo "Relay ON")
    else
        Etat_Relay=$(echo "Relay OFF")
    fi
}
function presentation() {
    echo
    echo "╔═ ÉCOLE D’INGÉNIEURS SUP GALILÉE"
    echo "╠═ INSTRUMENTATION ING 2"
    echo "╠═ PROJET LINUX POUR L'EMBARQUÉ"
    echo "╚═ Edward PAEZ ©2020, Encadrant M. Walid ABDAOUI"
    echo
    echo "═══════════════════════════════════════════"
    echo "♦ Adresse IP de la RPI: $myip"
    echo "♦ Adresse IP publique de la RPI: $myip_p"
    echo "♦ Température du CPU et GPU"
    echo "	▬ Temp.CPU ► $TempCPU"
    echo "	▬ Temp.GPU ► $TempGPU"
    echo "	▬ Volt.CPU ► $VoltCPU"
    echo "♦ Nom de la RPI : $myHost"
    echo "♦ Date et heure : Nous somme le $UtcNow"
    echo "♦ Capteur DS18B20 branché sur les GPIO-04 : $tempDS18B20 °C "
    echo "♦ L'actionneur Relais branché sur les GPIO-17 : $EtatPin_17; $Etat_Relay "
    echo "═══════════════════════════════════════════"
}

function actionneur() {
    tempDS18B20_in=$(echo ${tempDS18B20%.*}) #Pour avoir un integer
    #-gt	greater than	x > y
    if [ $tempDS18B20_in -gt 25 ]; then
        #On met la broche 17 à un niveau bas
        echo "0" >/sys/class/gpio/gpio17/value
    else
        #On met la broche 17 en position haute
        echo "1" >/sys/class/gpio/gpio17/value
    fi
}

while [ 1 ]; do

    actualiser_variables
    Data=$(echo "$myip;$myip_p;$TempCPU;$TempGPU;$VoltCPU;$myHost;$UtcNow;$tempDS18B20;$Etat_Relay")
    #echo "$Data" #Pour debug
    actionneur
    $(mosquitto_pub -h localhost -t raspEdward/data -m "$Data")
    presentation
    
done
