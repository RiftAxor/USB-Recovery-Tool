<div align="center">

# 🛠️ USB Recovery & Deep Format Tool

**Herramienta multiplataforma para rescate, limpieza de bajo nivel y reconstrucción de memorias USB, tarjetas SD y unidades extraíbles dañadas.**

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green?style=for-the-badge&logo=gnubash&logoColor=white)](https://github.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 📌 ¿Por qué existe esta herramienta?

En muchas ocasiones, Windows, macOS o Linux fallan al formatear una memoria USB, mostrando errores como:
* *"Windows no pudo completar el formato"*
* *"El volumen no contiene un sistema de archivos reconocido (RAW)"*
* *"Parámetro no válido" o "Pista 0 defectuosa (Offset 0 / Superfloppy)"*
* *"El disco está protegido contra escritura"*
* Espacio reducido a unos pocos megabytes tras usar **Rufus, BalenaEtcher o Ventoy**.
* Tarjetas SD con particiones Linux (`ext4`) de **Raspberry Pi, Nintendo Switch o cámaras** que no se dejan borrar.

Esta suite automatiza la **limpieza a bajo nivel**, destruye particiones híbridas/OEM bloqueadas, refresca la caché de almacenamiento del kernel y reconstruye la unidad con un esquema **MBR estándar en formato exFAT / NTFS / FAT32**.

---

## 🖥️ Características Principales

- **Menú interactivo con 5 módulos especializados:**
  1. 🟢 **Recuperación profunda:** Para unidades en modo RAW, offset 0 o corruptas.
  2. 🟡 **Restaurar USB booteable:** Devuelve el 100% del tamaño original en una sola partición limpia.
  3. 🔵 **Desbloquear solo lectura:** Limpia atributos de software de protección contra escritura sin borrar datos.
  4. 🟣 **Diagnóstico de salud:** Inspecciona el visor de eventos del kernel en busca de fallas físicas de memoria NAND (I/O timeouts / Evento 153).
  5. ⚪ **Formateo rápido a medida:** Elige entre `exFAT`, `NTFS` o `FAT32` con nombre personalizado.
- **Selección inteligente de unidad:** Puedes elegir la unidad escribiendo su **letra** (ej. `E` o `E:`), su **número de lista** o su **disco físico**.
- **Seguridad anti-desastres:** Detecta automáticamente el disco donde está instalado el sistema operativo (`C:\` / NVMe) y **lo bloquea para impedir cualquier borrado accidental**.
- **Multiplataforma:** Soporte nativo para Windows (`.bat` + `.ps1`), Linux y macOS (`.sh`).

---

## 🚀 Guía de Uso Rápido

### 🪟 En Windows

1. Descarga o clona el repositorio.
2. Haz **doble clic** sobre:
   ```cmd
   Ejecutar_Como_Administrador.bat
   ```
   *(Si el sistema solicita permisos de Administrador, pulsa **"Sí"**)*.
3. Elige la acción deseada en el menú principal y sigue las instrucciones en pantalla.

```text
======================================================================
         HERRAMIENTA PROFESIONAL DE GESTION Y RESCATE DE USBs         
======================================================================

  [1]  RECUPERACION PROFUNDA (Para USBs que no se dejan formatear / RAW / Danadas)
  [2]  RESTAURAR USB BOOTEABLE (Recuperar espacio perdido por Rufus, Etcher o Ventoy)
  [3]  QUITAR PROTECCION CONTRA ESCRITURA (Desbloquear modo Solo Lectura / Read-Only)
  [4]  DIAGNOSTICO DE SALUD Y EVENTOS (Comprobar si el chip de memoria esta vivo o muerto)
  [5]  FORMATEO RAPIDO A MEDIDA (Elegir exFAT, NTFS o FAT32 + Nombre personalizado)

  [0]  SALIR
======================================================================
```

---

### 🐧 En Linux

1. Abre tu terminal en la carpeta del proyecto.
2. Dale permisos de ejecución al script (solo la primera vez):
   ```bash
   chmod +x recuperar_usb.sh
   ```
3. Ejecútalo como superusuario:
   ```bash
   sudo ./recuperar_usb.sh
   ```
4. El script usará `lsblk` para mostrar las unidades externas, protegerá tu disco raíz `/`, destruirá metadatos corruptos con `wipefs` / `dd` y creará la nueva partición con `parted` y `mkfs.exfat`.

---

### 🍎 En macOS (Apple Silicon & Intel)

1. Abre la aplicación **Terminal** en tu Mac.
2. Ejecútalo con privilegios de administrador:
   ```bash
   sudo bash recuperar_usb.sh
   ```
3. El script filtrará automáticamente las unidades con `diskutil list external`, protegerá `disk0` (tu almacenamiento interno), destruirá tablas GPT residuales con `gpt destroy` y reconstruirá la memoria en formato limpio `exFAT`.

---

## 📁 Estructura del Repositorio

```text
USB-Recovery-Tool/
├── .gitignore                   # Archivos y logs ignorados por Git
├── CONTRIBUTING.md              # Guía de contribución para colaboradores
├── LICENSE                      # Licencia MIT Open Source
├── README.md                    # Documentación oficial del proyecto
├── Ejecutar_Como_Administrador.bat # Lanzador de 1 clic para Windows con elevación UAC
├── Recuperar_USB.ps1            # Motor interactivo modular para Windows (PowerShell)
└── recuperar_usb.sh             # Script universal en Bash para Linux y macOS
```

---

## ⚠️ Advertencia y Descargo de Responsabilidad

* Este software realiza operaciones de bajo nivel (borrado de tablas de particiones, inicialización MBR y formateo). Asegúrate siempre de verificar la letra o número de la unidad antes de confirmar con **`SI`**.
* Si una memoria USB sufre **muerte física de hardware** (chip NAND agotado o cortocircuito interno que arroja error *0xc000000e* / *Dispositivo que no existe*), ninguna herramienta de software en ningún sistema operativo podrá repararla, ya que el circuito se apaga por protección eléctrica.

---

## 📄 Licencia

Este proyecto está bajo la Licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.
