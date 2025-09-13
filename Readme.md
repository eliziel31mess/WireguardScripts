Creamos un Script para instalar y configurar Wireguard

✅ SCRIPT: install-wireguard-auto.sh

```bash
sudo nano install-wireguard-auto.sh
```

```sh
#!/bin/bash
# Script para instalar y configurar WireGuard en Debian/Ubuntu
# Crea interfaz wg0 y te deja listo para agregar peers.

set -e  # Salir si algún comando falla

echo "🚀 Instalando y configurando WireGuard..."

# 1. Actualizar sistema
echo "🔄 Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

# 2. Instalar WireGuard
echo "⬇️  Instalando WireGuard..."
sudo apt install -y wireguard resolvconf qrencode

# 3. Habilitar IP forwarding
echo "🌐 Habilitando IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf

# 4. Generar claves
echo "🔑 Generando claves de WireGuard..."
umask 077
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

# 5. Crear directorio de configuración
echo "📁 Creando directorio /etc/wireguard..."
sudo mkdir -p /etc/wireguard

# 6. Crear archivo de configuración del servidor
echo "📝 Creando /etc/wireguard/wg0.conf..."
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

# 7. Dar permisos seguros al archivo de configuración
sudo chmod 600 /etc/wireguard/wg0.conf

# 8. Habilitar e iniciar el servicio
echo "⚡ Activando y levantando wg0..."
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# 9. Configurar firewall (UFW)
echo "🛡️  Configurando UFW..."
sudo ufw allow 51820/udp
sudo ufw reload

# 10. Mostrar clave pública del servidor
echo ""
echo "✅ ¡WireGuard instalado y configurado!"
echo ""
echo "🔑 Clave pública del servidor (necesaria para los peers):"
echo "$SERVER_PUBLIC_KEY"
echo ""
echo "📌 Para crear un peer, usa el script: ./add-peer.sh NOMBRE"
echo "   Ejemplo: ./add-peer.sh laptop"
echo ""
echo "🌐 Conéctate a: 10.8.0.1 (servidor) desde los clientes."
echo ""
```

✅ SCRIPT: `add-peer.sh` (para crear peers fácilmente)

```bash
sudo nano add-peer.sh
```

```sh
#!/bin/bash
# Script para agregar un nuevo peer a WireGuard

if [ $# -eq 0 ]; then
    echo "❌ Uso: $0 nombre_del_peer"
    echo "   Ejemplo: $0 laptop"
    exit 1
fi

PEER_NAME="$1"
PEER_DIR="/etc/wireguard/peers"
PEER_FILE="$PEER_DIR/${PEER_NAME}.conf"

# Crear directorio para peers
sudo mkdir -p "$PEER_DIR"

# Generar claves para el peer
PEER_PRIVATE_KEY=$(wg genkey)
PEER_PUBLIC_KEY=$(echo "$PEER_PRIVATE_KEY" | wg pubkey)

# IP del peer (busca la siguiente IP disponible)
LAST_IP=$(sudo grep -h "AllowedIPs" /etc/wireguard/wg0.conf 2>/dev/null | grep -o "10\.8\.0\.[0-9]*" | sort -V | tail -1)
if [ -z "$LAST_IP" ]; then
    PEER_IP="10.8.0.2"
else
    # Extraer último número y sumar 1
    LAST_NUM=$(echo "$LAST_IP" | cut -d. -f4)
    NEXT_NUM=$((LAST_NUM + 1))
    PEER_IP="10.8.0.$NEXT_NUM"
fi

# Agregar peer al servidor
echo "### Peer: $PEER_NAME" | sudo tee -a /etc/wireguard/wg0.conf
echo "PublicKey = $PEER_PUBLIC_KEY" | sudo tee -a /etc/wireguard/wg0.conf
echo "AllowedIPs = $PEER_IP/32" | sudo tee -a /etc/wireguard/wg0.conf
echo "" | sudo tee -a /etc/wireguard/wg0.conf

# Recargar configuración de WireGuard
sudo systemctl reload wg-quick@wg0

# Crear archivo de configuración para el cliente
sudo tee "$PEER_FILE" > /dev/null <<EOF
[Interface]
PrivateKey = $PEER_PRIVATE_KEY
Address = $PEER_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $(sudo grep PrivateKey /etc/wireguard/wg0.conf | head -1 | awk '{print $3}' | wg pubkey)
Endpoint = $(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Mostrar QR y archivo
echo ""
echo "✅ Peer '$PEER_NAME' creado con IP: $PEER_IP"
echo "📄 Archivo de configuración: $PEER_FILE"
echo "📱 Escanea este QR para configurar en móvil:"
qrencode -t ansiutf8 < "$PEER_FILE"
echo ""
echo "💡 Para activar cambios en el servidor, reinicia:"
echo "   sudo systemctl restart wg-quick@wg0"
```

🚀 ¿CÓMO USARLO?

➤ Paso 1: Guarda los scripts
```bash
nano install-wireguard-auto.sh
# Pega el primer script, guarda y cierra (Ctrl+O, Enter, Ctrl+X)

nano add-peer.sh
# Pega el segundo script, guarda y cierra
```

➤ Paso 2: Hazlos ejecutables
```bash
chmod +x install-wireguard-auto.sh add-peer.sh
```

➤ Paso 3: Ejecuta la instalación
```bash
sudo ./install-wireguard-auto.sh
```

✅ Te mostrará la clave pública del servidor → ¡guárdala, la necesitarás si configuras peers manualmente!

➤ Paso 4: Crea un peer
```bash
sudo ./add-peer.sh laptop
```

✅ Te generará:

- Un archivo laptop.conf en /etc/wireguard/peers/.
- Un QR para escanear desde tu móvil.
- Lo agregará automáticamente al servidor.

✅ RESUMEN FINAL
```bash
# Instalar WireGuard
sudo ./install-wireguard-auto.sh

# Crear peers
sudo ./add-peer.sh laptop
sudo ./add-peer.sh iphone
sudo ./add-peer.sh trabajo
```

✅ Descargando Scripts

```bash
wget -O install-wireguard-auto.sh https://raw.githubusercontent.com/eliziel31mess/WireguardScripts/refs/heads/master/install-wireguard-auto.sh
```

```bash
wget -O add-peer.sh https://raw.githubusercontent.com/eliziel31mess/WireguardScripts/refs/heads/master/add-peer.sh
```