.\ZugChainDeposit.exe new-mnemonic --regular-withdrawal --num_validators 1 --chain zugchain




scp -i "C:\Users\DARK\Desktop\machine1\mainMachine.pem" "dist\validator_keys\keystore-*.json" ubuntu@ec2-16-170-206-38.eu-north-1.compute.amazonaws.com:/home/ubuntu/

# 1. Repo'yu clone edin
cd ~
git clone https://github.com/CadaFinance/zugchain-validator-kit.git

# 2. Keystore'u validator_keys klasörüne koyun
mkdir -p ~/validator_keys
mv ~/keystore-*.json ~/validator_keys/

# 3. Setup.sh'yi çalıştırın
cd zugchain-validator-kit/scripts
sudo bash setup.sh



Path sorusu: /home/ubuntu/validator_keys yazın