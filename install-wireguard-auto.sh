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