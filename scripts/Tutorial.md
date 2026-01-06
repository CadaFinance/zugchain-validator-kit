




./deposit.exe new-mnemonic --num_validators=1


# 1. Repo'yu clone edin
cd ~
git clone https://github.com/CadaFinance/zugchain-validator-kit.git

## pc de keyleri gonder

makine urlini degistir

scp -r -i "C:\Users\DARK\Desktop\machine1\mainMachine.pem" "C:\Users\DARK\Desktop\validator_keys" ubuntu@ec2-51-20-41-97.eu-north-1.compute.amazonaws.com:/home/ubuntu/

# 2. Keystore'u validator_keys klasörüne koyun
mkdir -p ~/validator_keys
mv ~/keystore-*.json ~/validator_keys/

# 3. Setup.sh'yi çalıştırın
cd zugchain-validator-kit/scripts
sudo bash setup.sh



Path sorusu: /home/ubuntu/validator_keys yazın