-include .env

build:; forge build

deploy-goerli:
	forge script script/CompoundV2ERC4626.s.sol:DeployCompoundV2ERC4626 --rpc-url $(GOERLI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-stEth:
	forge script script/stETHSwap.s.sol:DeployStEthSwap --rpc-url $(GOERLI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv