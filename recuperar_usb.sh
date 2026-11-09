#!/bin/bash
# ======================================================================
#   HERRAMIENTA UNIVERSAL DE RECUPERACION DE USB (LINUX & MACOS)
# ======================================================================

# Comprobar privilegios de root/sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[ERROR] Este script requiere privilegios de superusuario (root).\033[0m"
    echo -e "Ejecutalo con: \033[1;33msudo bash $0\033[0m"
    exit 1
fi

OS_TYPE="$(uname -s)"

# Funcion para listar discos y seleccionar en Linux
select_disk_linux() {
    echo -e "\n\033[1;33mDiscos detectados en tu equipo:\033[0m"
    echo "----------------------------------------------------------------------"
    lsblk -d -o NAME,SIZE,MODEL,TRAN,RM,RO,TYPE
    echo "----------------------------------------------------------------------"
    echo -e "\033[1;36mConsejo: Las USBs suelen ser sdb, sdc, sdd (tipo 'usb' / RM=1).\033[0m"
    echo -e "\033[1;31mNUNCA selecciones el disco de tu sistema (sda / nvme0n1).\033[0m\n"

    read -p "Escribe el nombre del disco (ejemplo: sdb): " TARGET
    TARGET="/dev/${TARGET#/dev/}"

    if [ ! -b "$TARGET" ]; then
        echo -e "\033[1;31m[ERROR] El dispositivo $TARGET no existe.\033[0m"
        return 1
    fi

    # Proteccion contra formatear el disco del sistema
    ROOT_DISK=$(lsblk -no PKNAME $(findmnt -n -o SOURCE /) 2>/dev/null)
    if [ "$TARGET" = "/dev/$ROOT_DISK" ]; then
        echo -e "\033[1;31m[BLOQUEADO] Has seleccionado el disco donde esta instalado tu sistema operativo!\033[0m"
        return 1
    fi

    echo -e "\n\033[1;37;41m ATENCION: Se borraran todos los datos en $TARGET \033[0m"
    read -p "Estas seguro? Escribe 'SI' para proceder: " CONFIRM
    if [ "$CONFIRM" != "SI" ]; then
        echo "Operacion cancelada."
        return 1
    fi
    return 0
}

# Funcion para listar discos y seleccionar en macOS
select_disk_macos() {
    echo -e "\n\033[1;33mDiscos detectados en tu Mac:\033[0m"
    echo "----------------------------------------------------------------------"
    diskutil list external
    echo "----------------------------------------------------------------------"
    echo -e "\033[1;36mConsejo: Tu disco interno de macOS siempre es disk0.\033[0m\n"

    read -p "Escribe el identificador del disco (ejemplo: disk2): " TARGET
    TARGET="${TARGET#/dev/}"

    if [ "$TARGET" = "disk0" ] || [ "$TARGET" = "disk1" ]; then
        echo -e "\033[1;31m[BLOQUEADO] No puedes formatear el disco interno de macOS ($TARGET)!\033[0m"
        return 1
    fi

    TARGET="/dev/$TARGET"
    if [ ! -b "$TARGET" ]; then
        echo -e "\033[1;31m[ERROR] El dispositivo $TARGET no existe.\033[0m"
        return 1
    fi

    echo -e "\n\033[1;37;41m ATENCION: Se borraran todos los datos en $TARGET \033[0m"
    read -p "Estas seguro? Escribe 'SI' para proceder: " CONFIRM
    if [ "$CONFIRM" != "SI" ]; then
        echo "Operacion cancelada."
        return 1
    fi
    return 0
}

# Recuperacion profunda en Linux
recovery_linux() {
    select_disk_linux || return

    echo -e "\n\033[1;33m[1/4] Desmontando particiones activas en $TARGET...\033[0m"
    umount ${TARGET}* 2>/dev/null

    echo -e "\033[1;33m[2/4] Destruyendo firmas y metadatos corruptos (wipefs)...\033[0m"
    wipefs -a -f $TARGET 2>/dev/null
    dd if=/dev/zero of=$TARGET bs=1M count=10 conv=fsync status=none 2>/dev/null

    echo -e "\033[1;33m[3/4] Creando tabla de particiones MBR y particion primaria...\033[0m"
    parted --script $TARGET mklabel msdos mkpart primary fat32 1MiB 100%
    partprobe $TARGET 2>/dev/null
    sleep 2

    # Detectar particion creada (ej. /dev/sdb1)
    PART="${TARGET}1"
    if [ ! -b "$PART" ]; then PART="${TARGET}p1"; fi

    echo -e "\033[1;33m[4/4] Formateando en exFAT (o FAT32)...\033[0m"
    if command -v mkfs.exfat &>/dev/null; then
        mkfs.exfat -n "USB" $PART
    else
        mkfs.vfat -F 32 -n "USB" $PART
    fi

    echo -e "\n\033[1;32m[EXITO] Memoria USB completamente recuperada y lista para usar!\033[0m\n"
}

# Recuperacion profunda en macOS
recovery_macos() {
    select_disk_macos || return

    echo -e "\n\033[1;33m[1/3] Desmontando disco completo en macOS...\033[0m"
    diskutil unmountDisk $TARGET

    echo -e "\033[1;33m[2/3] Borrando tablas GPT y estructuras MBR...\033[0m"
    gpt destroy $TARGET 2>/dev/null
    dd if=/dev/zero of=$TARGET bs=1m count=5 2>/dev/null

    echo -e "\033[1;33m[3/3] Reconstruyendo y formateando en exFAT con esquema MBR...\033[0m"
    diskutil eraseDisk ExFAT "USB" MBR $TARGET

    echo -e "\n\033[1;32m[EXITO] Memoria USB completamente recuperada en tu Mac!\033[0m\n"
}

# Bucle del menu principal
while true; do
    echo -e "\033[1;36m======================================================================\033[0m"
    echo -e "\033[1;36m   HERRAMIENTA UNIVERSAL DE RECUPERACION DE USB ($OS_TYPE)          \033[0m"
    echo -e "\033[1;36m======================================================================\033[0m"
    echo -e "  [1] RECUPERACION PROFUNDA Y FORMATO COMPLETO (exFAT / MBR)"
    echo -e "  [2] BORRADO DE FIRMAS CORRUPTAS / RESTAURAR USB BOOTEABLE"
    echo -e "  [0] SALIR"
    echo -e "\033[1;36m======================================================================\033[0m"
    read -p "Selecciona una opcion (0-2): " OPT

    case $OPT in
        1)
            if [ "$OS_TYPE" = "Darwin" ]; then recovery_macos; else recovery_linux; fi
            read -p "Presiona Enter para continuar..."
            ;;
        2)
            if [ "$OS_TYPE" = "Darwin" ]; then recovery_macos; else recovery_linux; fi
            read -p "Presiona Enter para continuar..."
            ;;
        0)
            echo "Hasta luego!"
            exit 0
            ;;
        *)
            echo "Opcion no valida."
            sleep 1
            ;;
    esac
done
