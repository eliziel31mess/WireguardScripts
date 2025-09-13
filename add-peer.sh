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