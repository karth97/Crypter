>> clone the repo
cd Crypter

>> Create payload (name it as test_payload.exe)
msfvenom -p windows/x64/messagebox TEXT="Loader Test" TITLE="Success" -f exe -o test_payload.exe 2>/dev/null

>> Run
chmod +x build_manual.sh
./build_manual.sh
