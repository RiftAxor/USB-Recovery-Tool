# ======================================================================
#         HERRAMIENTA MODULAR DE RECUPERACION Y GESTION DE USBs
# ======================================================================
$ErrorActionPreference = "Continue"
$ConfirmPreference = "None"

# 1. Comprobar permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host "       [ERROR CRITICO] SE REQUIEREN PERMISOS DE ADMINISTRADOR        " -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host "`nEste script necesita privilegios de Administrador para gestionar discos." -ForegroundColor Yellow
    Write-Host "Por favor, ejecuta el archivo 'Ejecutar_Como_Administrador.bat'." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# ======================================================================
# FUNCION AVANZADA DE SELECCION DE UNIDAD (Por Letra E:, F: o Numero)
# ======================================================================
function Select-TargetDrive {
    param (
        [string]$Operacion = "OPERACION"
    )

    do {
        Clear-Host
        Write-Host "======================================================================" -ForegroundColor Cyan
        Write-Host "       SELECCIONA LA UNIDAD USB A TRABAJAR ($Operacion)              " -ForegroundColor Cyan
        Write-Host "======================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Escaneando unidades de almacenamiento conectadas..." -ForegroundColor Yellow

        $allDisks = Get-Disk | Sort-Object Number
        $systemDiskNums = @($allDisks | Where-Object { $_.IsSystem -or $_.IsBoot } | ForEach-Object { $_.Number })

        # Obtener informacion combinada de discos, particiones y volumenes
        $usbList = @()
        $counter = 1

        foreach ($disk in $allDisks) {
            # Omitir discos de sistema de las opciones seleccionables
            if ($disk.Number -in $systemDiskNums) { continue }

            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue
            
            # Recolectar letras asociadas
            $letters = @()
            $fsTypes = @()
            foreach ($p in $partitions) {
                if ($p.DriveLetter) {
                    $letters += "$($p.DriveLetter):"
                    $vol = Get-Volume -DriveLetter $p.DriveLetter -ErrorAction SilentlyContinue
                    if ($vol -and $vol.FileSystemType) { $fsTypes += $vol.FileSystemType }
                }
            }

            $letterStr = if ($letters.Count -gt 0) { $letters -join ", " } else { "(Sin letra / RAW)" }
            $fsStr = if ($fsTypes.Count -gt 0) { ($fsTypes | Select-Object -Unique) -join "/" } else { "RAW / Desconocido" }

            $usbList += [PSCustomObject]@{
                Index        = $counter
                DiskNumber   = $disk.Number
                DriveLetters = $letterStr
                LettersArray = $letters
                FriendlyName = $disk.FriendlyName
                SizeGB       = "$sizeGB GB"
                BusType      = $disk.BusType
                FileSystem   = $fsStr
                Status       = $disk.OperationalStatus
                DiskObject   = $disk
            }
            $counter++
        }

        # Si no se detectaron unidades extraibles o secundarias
        if ($usbList.Count -eq 0) {
            Write-Host "`n[AVISO] No se detecto ninguna memoria USB o disco secundario conectado." -ForegroundColor Yellow
            Write-Host "Discos internos del sistema protegidos: Disco(s) $($systemDiskNums -join ', ')" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  [R] Reintentar / Escanear de nuevo" -ForegroundColor Green
            Write-Host "  [C] Cancelar y volver al menu principal" -ForegroundColor Red
            Write-Host ""
            $retry = Read-Host "Elige una opcion (R/C)"
            if ($retry.Trim().ToUpper() -eq "R") { continue } else { return $null }
        }

        Write-Host "Unidades disponibles detectadas:" -ForegroundColor Green
        Write-Host "------------------------------------------------------------------------------------------------"
        Write-Host ("{0,-4} {1,-14} {2,-26} {3,-10} {4,-12} {5,-10}" -f "#", "LETRA(S)", "NOMBRE / MODELO", "TAMANO", "FORMATO", "DISCO FISICO")
        Write-Host "------------------------------------------------------------------------------------------------"

        foreach ($item in $usbList) {
            $color = if ($item.BusType -eq "USB") { "Cyan" } else { "White" }
            Write-Host ("[{0}]  {1,-14} {2,-26} {3,-10} {4,-12} Disco {5} ({6})" -f $item.Index, $item.DriveLetters, $item.FriendlyName, $item.SizeGB, $item.FileSystem, $item.DiskNumber, $item.BusType) -ForegroundColor $color
        }
        Write-Host "------------------------------------------------------------------------------------------------"
        Write-Host "Discos del Sistema Operativo Windows (C:) estan OCULTOS y PROTEGIDOS automaticamente." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Puedes ingresar el NUMERO de la lista (ej: 1) o la LETRA de la unidad (ej: E o E:)" -ForegroundColor Yellow
        Write-Host "(O presiona Enter sin escribir nada para volver al menu principal)" -ForegroundColor Gray
        Write-Host ""

        $selection = Read-Host "Selecciona la unidad a trabajar"
        if ([string]::IsNullOrWhiteSpace($selection)) {
            return $null
        }

        $cleanSelection = $selection.Trim().ToUpper().Replace(":", "")

        # Buscar coincidencia por indice (1, 2...)
        $match = $usbList | Where-Object { $_.Index.ToString() -eq $cleanSelection }

        # Buscar coincidencia por letra (E, F...)
        if (-not $match) {
            $match = $usbList | Where-Object { 
                foreach ($l in $_.LettersArray) {
                    if ($l.Replace(":", "").ToUpper() -eq $cleanSelection) { return $true }
                }
                return $false
            }
        }

        # Buscar coincidencia por numero de disco fisico
        if (-not $match) {
            $match = $usbList | Where-Object { $_.DiskNumber.ToString() -eq $cleanSelection }
        }

        if (-not $match) {
            Write-Host "`n[ERROR] No se encontro ninguna unidad que coincida con '$selection'." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }

        Write-Host "`nUnidad seleccionada:" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "  -> Letra(s):   $($match.DriveLetters)" -ForegroundColor Cyan
        Write-Host "  -> Dispositivo: $($match.FriendlyName) ($($match.SizeGB))" -ForegroundColor Cyan
        Write-Host "  -> Disco #:    Disco $($match.DiskNumber)" -ForegroundColor Cyan
        Start-Sleep -Seconds 1
        return $match

    } while ($true)
}

# ======================================================================
# MODULO 1: RECUPERACION PROFUNDA
# ======================================================================
function Invoke-DeepRecovery {
    $drive = Select-TargetDrive -Operacion "RECUPERACION PROFUNDA"
    if (-not $drive) { return }

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "     OPCION 1: RECUPERACION PROFUNDA Y FORMATO COMPLETO               " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "Unidad elegida: Letra $($drive.DriveLetters) | Disco $($drive.DiskNumber) ($($drive.FriendlyName) - $($drive.SizeGB))" -ForegroundColor Green
    Write-Host ""
    Write-Host "[ADVERTENCIA]: Se limpiaran todas las particiones y metadatos danados." -ForegroundColor Yellow
    Write-Host "Esta accion reconstruira la unidad en formato limpio exFAT." -ForegroundColor Yellow
    $confirm = Read-Host "`nEscribe 'SI' para confirmar e iniciar"
    if ($confirm.Trim().ToUpper() -ne "SI") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        pause
        return
    }

    $targetNum = $drive.DiskNumber
    $logPath = Join-Path $PSScriptRoot "ultimo_proceso.log"
    try { Start-Transcript -Path $logPath -Force -ErrorAction SilentlyContinue } catch {}

    Write-Host "`nIniciando proceso de recuperacion en Disco $targetNum..." -ForegroundColor Cyan

    # 1. Quitar solo lectura
    Write-Host "[1/6] Removiendo atributos de solo lectura..." -ForegroundColor Yellow
    try { Set-Disk -Number $targetNum -IsReadOnly $false -ErrorAction SilentlyContinue } catch {}

    # 2. Desmontar letras de unidad
    Write-Host "[2/6] Desmontando letras de unidad y liberando bloqueos..." -ForegroundColor Yellow
    Get-Partition -DiskNumber $targetNum -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.DriveLetter) {
            Write-Host "  -> Desmontando $($_.DriveLetter):"
            Remove-PartitionAccessPath -DiskNumber $targetNum -PartitionNumber $_.PartitionNumber -AccessPath "$($_.DriveLetter):\" -ErrorAction SilentlyContinue
        }
        Remove-Partition -DiskNumber $targetNum -PartitionNumber $_.PartitionNumber -Confirm:$false -ErrorAction SilentlyContinue
    }

    # 3. Limpieza de metadatos OEM y Superfloppy
    Write-Host "[3/6] Limpiando metadatos corruptos y tablas de particion..." -ForegroundColor Yellow
    Clear-Disk -Number $targetNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # 4. Refresco de cache de almacenamiento
    Write-Host "[4/6] Actualizando cache de almacenamiento del kernel..." -ForegroundColor Yellow
    Update-HostStorageCache
    Start-Sleep -Seconds 1

    # 5. Inicializar en MBR
    Write-Host "[5/6] Inicializando en tabla de particiones MBR..." -ForegroundColor Yellow
    Initialize-Disk -Number $targetNum -PartitionStyle MBR -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    # 6. Particionar y Formatear
    Write-Host "[6/6] Creando particion primaria completa y formateando..." -ForegroundColor Yellow
    $success = $false

    try {
        $part = New-Partition -DiskNumber $targetNum -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
        Start-Sleep -Seconds 2
        try {
            Write-Host "  -> Aplicando formato en exFAT..."
            Format-Volume -Partition $part -FileSystem exFAT -NewFileSystemLabel "USB" -Confirm:$false -ErrorAction Stop
            $success = $true
        } catch {
            Write-Host "  -> exFAT no soportado, formateando en NTFS..." -ForegroundColor Yellow
            Format-Volume -Partition $part -FileSystem NTFS -NewFileSystemLabel "USB" -Confirm:$false -ErrorAction Stop
            $success = $true
        }
    } catch {
        Write-Host "  -> Aplicando metodo DiskPart de bajo nivel como contingencia..." -ForegroundColor Cyan
        $dpScript = @"
select disk $targetNum
attributes disk clear readonly
clean
rescan
create partition primary
select partition 1
active
format fs=exfat quick label="USB"
assign
exit
"@
        $dpFile = Join-Path $PSScriptRoot "temp_diskpart.txt"
        $dpScript | Out-File -FilePath $dpFile -Encoding ascii
        & diskpart /s $dpFile
        Remove-Item -Path $dpFile -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        if (Get-Partition -DiskNumber $targetNum -ErrorAction SilentlyContinue) {
            $success = $true
        }
    }

    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    Write-Host "`n----------------------------------------------------------------------"
    if ($success) {
        Write-Host " [EXITO] Memoria recuperada y formateada con exito!" -ForegroundColor Green
        Write-Host " Ya puedes verla y usarla normalmente en el Explorador de archivos." -ForegroundColor Green
    } else {
        Write-Host " [RESULTADO] La memoria no respondio a los comandos de escritura." -ForegroundColor Red
        Write-Host " Si la memoria se desconecto, presenta dano fisico irreversible (NAND agotada)." -ForegroundColor Yellow
    }
    Write-Host "----------------------------------------------------------------------`n"
    pause
}

# ======================================================================
# MODULO 2: RESTAURAR USB BOOTEABLE (Rufus, Balena, Ventoy)
# ======================================================================
function Invoke-RestoreBootableUSB {
    $drive = Select-TargetDrive -Operacion "RESTAURAR USB BOOTEABLE"
    if (-not $drive) { return }

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "   OPCION 2: RESTAURAR USB BOOTEABLE Y RECUPERAR ESPACIO PERDIDO      " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "Unidad elegida: Letra $($drive.DriveLetters) | Disco $($drive.DiskNumber) ($($drive.FriendlyName) - $($drive.SizeGB))" -ForegroundColor Green
    Write-Host ""
    Write-Host "Se eliminaran las particiones residuales para recuperar el espacio total." -ForegroundColor Yellow
    $confirm = Read-Host "Escribe 'SI' para continuar"
    if ($confirm.Trim().ToUpper() -ne "SI") { return }

    $targetNum = $drive.DiskNumber
    Write-Host "`nEliminando particiones multiples y restaurando capacidad..." -ForegroundColor Cyan

    Get-Partition -DiskNumber $targetNum -ErrorAction SilentlyContinue | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue
    Clear-Disk -Number $targetNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue
    Update-HostStorageCache
    Initialize-Disk -Number $targetNum -PartitionStyle MBR -ErrorAction SilentlyContinue
    $part = New-Partition -DiskNumber $targetNum -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition $part -FileSystem exFAT -NewFileSystemLabel "USB" -Confirm:$false

    Write-Host "`n[EXITO] Espacio total recuperado en una sola particion limpia (exFAT)!" -ForegroundColor Green
    pause
}

# ======================================================================
# MODULO 3: QUITAR PROTECCION CONTRA ESCRITURA (Read-Only)
# ======================================================================
function Invoke-ClearReadOnly {
    $drive = Select-TargetDrive -Operacion "QUITAR SOLO LECTURA"
    if (-not $drive) { return }

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "     OPCION 3: DESBLOQUEAR MODO SOLO LECTURA (READ-ONLY)              " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "Unidad elegida: Letra $($drive.DriveLetters) | Disco $($drive.DiskNumber) ($($drive.FriendlyName))" -ForegroundColor Green

    $targetNum = $drive.DiskNumber
    Write-Host "`nRemoviendo banderas de solo lectura sin borrar archivos..." -ForegroundColor Cyan

    try { Set-Disk -Number $targetNum -IsReadOnly $false -ErrorAction SilentlyContinue } catch {}

    $dpScript = @"
select disk $targetNum
attributes disk clear readonly
attributes volume clear readonly
exit
"@
    $dpFile = Join-Path $PSScriptRoot "temp_ro.txt"
    $dpScript | Out-File -FilePath $dpFile -Encoding ascii
    & diskpart /s $dpFile
    Remove-Item -Path $dpFile -Force -ErrorAction SilentlyContinue

    Write-Host "`n[PROCESO COMPLETADO] Banderas de solo lectura limpiadas." -ForegroundColor Green
    Write-Host "Prueba a copiar o eliminar un archivo en la memoria ahora." -ForegroundColor Yellow
    pause
}

# ======================================================================
# MODULO 4: DIAGNOSTICO DE SALUD Y EVENTOS
# ======================================================================
function Invoke-HardwareDiagnostic {
    $drive = Select-TargetDrive -Operacion "DIAGNOSTICO"
    if (-not $drive) { return }

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "         OPCION 4: DIAGNOSTICO DE SALUD Y EVENTOS                     " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "Unidad elegida: Letra $($drive.DriveLetters) | Disco $($drive.DiskNumber) ($($drive.FriendlyName))" -ForegroundColor Green

    $targetNum = $drive.DiskNumber
    $dObj = $drive.DiskObject
    Write-Host "`nAnalisis de estado fisico y logico:" -ForegroundColor Cyan
    Write-Host "  -> Estado Operacional: $($dObj.OperationalStatus)"
    Write-Host "  -> Estado de Salud:    $($dObj.HealthStatus)"
    Write-Host "  -> Solo Lectura:       $($dObj.IsReadOnly)"
    Write-Host "  -> Tipo de Bus:        $($dObj.BusType)"
    Write-Host "  -> Esquema Particion:  $($dObj.PartitionStyle)"

    $partitions = Get-Partition -DiskNumber $targetNum -ErrorAction SilentlyContinue
    Write-Host "`nParticiones detectadas: $(@($partitions).Count)"
    foreach ($p in $partitions) {
        $pSizeGB = [math]::Round($p.Size / 1GB, 2)
        Write-Host "  - Particion $($p.PartitionNumber): Letra $($p.DriveLetter): | Offset: $($p.Offset) | Tamano: $pSizeGB GB | Tipo: $($p.Type)"
    }

    Write-Host "`nBuscando eventos de advertencia o I/O timeouts en el kernel..." -ForegroundColor Yellow
    $diskEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='disk'} -MaxEvents 5 -ErrorAction SilentlyContinue
    if ($diskEvents) {
        Write-Host "Ultimos eventos del driver de disco de Windows:" -ForegroundColor Magenta
        foreach ($ev in $diskEvents) {
            Write-Host "  [$($ev.TimeCreated)] ID $($ev.Id): $($ev.Message)"
        }
    } else {
        Write-Host "  No se registraron alertas criticas recientes de disco en el sistema." -ForegroundColor Green
    }

    Write-Host "`nDiagnostico completado." -ForegroundColor Cyan
    pause
}

# ======================================================================
# MODULO 5: FORMATEO RAPIDO A MEDIDA
# ======================================================================
function Invoke-QuickFormatCustom {
    $drive = Select-TargetDrive -Operacion "FORMATEO RAPIDO"
    if (-not $drive) { return }

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "        OPCION 5: FORMATEO RAPIDO A MEDIDA                            " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "Unidad elegida: Letra $($drive.DriveLetters) | Disco $($drive.DiskNumber) ($($drive.FriendlyName) - $($drive.SizeGB))" -ForegroundColor Green

    Write-Host "`nSelecciona el Sistema de Archivos deseado:" -ForegroundColor Yellow
    Write-Host "  [1] exFAT  (Recomendado: Compatible con Windows, Mac, Linux y Smart TVs; archivos > 4GB)"
    Write-Host "  [2] NTFS   (Ideal para Windows y discos duros externos)"
    Write-Host "  [3] FAT32  (Para radios de coche, consolas retro; max 4GB por archivo)"
    Write-Host ""
    $fsChoice = Read-Host "Elige una opcion (1, 2 o 3)"

    $chosenFS = switch ($fsChoice) {
        "1" { "exFAT" }
        "2" { "NTFS" }
        "3" { "FAT32" }
        default { "exFAT" }
    }

    $label = Read-Host "Ingresa el nombre/etiqueta para la USB (o presiona Enter para 'USB')"
    if ([string]::IsNullOrWhiteSpace($label)) { $label = "USB" }

    Write-Host "`nSe formateara la unidad en $chosenFS con nombre '$label'." -ForegroundColor Yellow
    $confirm = Read-Host "Escribe 'SI' para confirmar el formateo"
    if ($confirm.Trim().ToUpper() -ne "SI") { return }

    $targetNum = $drive.DiskNumber
    Write-Host "`nAplicando formato..." -ForegroundColor Cyan

    Get-Partition -DiskNumber $targetNum -ErrorAction SilentlyContinue | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue
    Initialize-Disk -Number $targetNum -PartitionStyle MBR -ErrorAction SilentlyContinue
    $part = New-Partition -DiskNumber $targetNum -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition $part -FileSystem $chosenFS -NewFileSystemLabel $label -Confirm:$false

    Write-Host "`n[EXITO] Formateo completado con exito en $chosenFS!" -ForegroundColor Green
    pause
}

# ======================================================================
# BUCLE DEL MENU PRINCIPAL
# ======================================================================
do {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "         HERRAMIENTA PROFESIONAL DE GESTION Y RESCATE DE USBs         " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1]  RECUPERACION PROFUNDA (Para USBs que no se dejan formatear / RAW / Danadas)" -ForegroundColor Green
    Write-Host "  [2]  RESTAURAR USB BOOTEABLE (Recuperar espacio perdido por Rufus, Etcher o Ventoy)" -ForegroundColor Yellow
    Write-Host "  [3]  QUITAR PROTECCION CONTRA ESCRITURA (Desbloquear modo Solo Lectura / Read-Only)" -ForegroundColor Cyan
    Write-Host "  [4]  DIAGNOSTICO DE SALUD Y EVENTOS (Comprobar si el chip de memoria esta vivo o muerto)" -ForegroundColor Magenta
    Write-Host "  [5]  FORMATEO RAPIDO A MEDIDA (Elegir exFAT, NTFS o FAT32 + Nombre personalizado)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [0]  SALIR" -ForegroundColor Gray
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    $opcion = Read-Host "Selecciona una opcion (0-5)"

    switch ($opcion) {
        "1" { Invoke-DeepRecovery }
        "2" { Invoke-RestoreBootableUSB }
        "3" { Invoke-ClearReadOnly }
        "4" { Invoke-HardwareDiagnostic }
        "5" { Invoke-QuickFormatCustom }
        "0" { Write-Host "`nHasta luego!`n" -ForegroundColor Green; break }
        default { Write-Host "`nOpcion no valida. Intenta de nuevo." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($opcion -ne "0")
