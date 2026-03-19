#!/bin/bash

# Script de Configuração Android para S.F.C.P.C
# Este script resolve dependências de Java, licenças Android e udev rules.

set -e

echo "--- Iniciando Setup Android ---"

# 0. Limpar locks do dpkg/apt (se existirem)
echo "0. Limpando travas do gerenciador de pacotes..."
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock || true
sudo dpkg --configure -a || true

# 1. Configurar Java (Preferência: Android Studio -> Portátil -> APT)

# Tentar encontrar Java no Android Studio primeiro
AS_JAVA="/opt/android-studio/jbr/bin/java"
if [ ! -f "$AS_JAVA" ]; then AS_JAVA="/opt/android-studio/jre/bin/java"; fi

if [ -f "$AS_JAVA" ]; then
    echo "✅ Usando Java do Android Studio: $AS_JAVA"
    export JAVA_HOME=$(dirname $(dirname "$AS_JAVA"))
    export PATH="$JAVA_HOME/bin:$PATH"
else
    echo "🔍 Java do Android Studio não encontrado. Tentando alternatvias..."
    JDK_PORTABLE="$HOME/Android/jdk17"
    if [ ! -d "$JDK_PORTABLE" ]; then
        echo "🚀 Baixando JDK 17 portátil (Temurin)..."
        # Link mais estável (Adoptium Temurin 17)
        JDK_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.10_7.tar.gz"
        mkdir -p "$JDK_PORTABLE"
        if ! wget -O /tmp/jdk.tar.gz "$JDK_URL"; then
            echo "❌ Falha no download. Tente baixar manualmente em: $JDK_URL"
            exit 1
        fi
        tar -xzf /tmp/jdk.tar.gz -C "$JDK_PORTABLE" --strip-components=1
    fi
    export JAVA_HOME="$JDK_PORTABLE"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "✅ JDK portátil configurado em $JDK_PORTABLE"
fi

# 2. Configurar cmdline-tools
ANDROID_SDK="$HOME/Android/Sdk"
mkdir -p "$ANDROID_SDK"

if [ ! -d "$ANDROID_SDK/cmdline-tools/latest" ]; then
    echo "2. Instalando cmdline-tools..."
    CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    mkdir -p "$ANDROID_SDK/cmdline-tools"
    wget -q -O /tmp/cmdline-tools.zip "$CMDLINE_TOOLS_URL"
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-tmp
    mv /tmp/cmdline-tools-tmp/cmdline-tools "$ANDROID_SDK/cmdline-tools/latest"
    rm -rf /tmp/cmdline-tools-tmp /tmp/cmdline-tools.zip
fi

# 3. Aceitar licenças Android
echo "3. Aceitando licenças Android..."
yes | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --licenses --sdk_root="$ANDROID_SDK"

# 4. Configurar udev rules para USB (permissão adb)
echo "4. Configurando permissões USB (udev)..."
echo "Nota: Se pedir senha e estiver travado por lock, pule este passo e rode manualmente depois."
if [ ! -f "/etc/udev/rules.d/51-android.rules" ]; then
    sudo bash -c "cat > /etc/udev/rules.d/51-android.rules <<EOF
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"*\", MODE=\"0666\", GROUP=\"plugdev\"
EOF" || echo "Pulei udev rules por causa de erro de lock/permissão."
    sudo chmod a+r /etc/udev/rules.d/51-android.rules || true
    sudo udevadm control --reload-rules || true
fi

# 5. Reiniciar ADB (opcional)
echo "5. Tentando reiniciar servidor ADB..."
ADB_BIN="$ANDROID_SDK/platform-tools/adb"
if [ -f "$ADB_BIN" ]; then
    "$ADB_BIN" kill-server || true
    "$ADB_BIN" start-server || true
else
    adb kill-server 2>/dev/null || true
    adb start-server 2>/dev/null || true
fi

echo "-----------------------------------"
echo "--- ✅ Setup Concluído! ---"
echo "-----------------------------------"
echo "Para buildar o APK, rode estes comandos:"
echo ""
echo "export JAVA_HOME=$JAVA_HOME"
echo "export PATH=\$JAVA_HOME/bin:\$PATH"
echo "cd frontend"
echo "flutter build apk --debug"
