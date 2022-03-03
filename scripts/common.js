const fs = require('fs');
const ethers = require('ethers');
const Artifacts = require('../out/dapp.sol.json');

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

function encode4Byte(contract, name) {
  return contract.interface.getSighash(contract.interface.getFunction(name)).padEnd(66, '0');
}

function getContractFactory(path, name, deployer) {
  const artifact = Artifacts.contracts[path][name];
  return new ethers.ContractFactory(artifact.abi, artifact.evm.bytecode, deployer);
}

async function deployContract(name, factory, ...args) {
  const contract = await factory.deploy(...args);
  console.log(`${name}: ${contract.address}`);
  console.log(`  address: ${contract.address}`);
  console.log(`  txHash:  ${contract.deployTransaction.hash}`);
  await saveAddress(factory.signer, name, contract.address);
  return contract;
}

async function deployViaVaultFactory(vaultFactory, name, factory, encodedArgs) {
  const receipt = await (await vaultFactory.createVault(factory.address, encodedArgs, { gasLimit: 2000000 })).wait();
  const contract = factory.attach(receipt.events?.filter(x => { return x.event == 'VaultCreated'; })[0].args.instance);
  console.log(`${name}: ${contract.address}`);
  console.log(`  address: ${contract.address}`);
  console.log(`  txHash:  ${receipt.transactionHash}`);
  await saveAddress(factory.signer, name, contract.address);
  return contract;
}

async function saveAddress(signer, name, address) {
  const file = `${(await signer.provider.getNetwork()).chainId}.json`;
  const addr = (fs.existsSync(file)) ? JSON.parse(fs.readFileSync(file)) : {};
  const addrs = { ...addr, [name]: address };
  fs.writeFileSync(file, JSON.stringify(addrs, Object.keys(addrs).sort(), 2));
}

async function send(contract, method, ...args) {
  const gas = await contract.estimateGas[method](...args);
  return contract[method](...args, { gasLimit: gas.mul(130).div(100) });
}

async function sendAndWait(contract, method, ...args) {
  const gas = await contract.estimateGas[method](...args);
  return (await contract[method](...args, { gasLimit: gas.mul(130).div(100) })).wait();
}

async function setupContracts(deployer) {
  const file = `${(await deployer.provider.getNetwork()).chainId}.json`;
  const addr = JSON.parse(fs.readFileSync(file));

  const contracts = {
    deployer: getContractFactory('src/Deployer.sol', 'Deployer', deployer).attach(addr.deployer),
    tokenGov: getContractFactory('src/test/utils/TestERC20.sol', 'TestERC20', deployer).attach(addr.tokenGov),
    fiat: getContractFactory('lib/fiat/src/FIAT.sol', 'FIAT', deployer).attach(addr.fiat),
    codex: getContractFactory('lib/fiat/src/Codex.sol', 'Codex', deployer).attach(addr.codex),
    moneta: getContractFactory('lib/fiat/src/Moneta.sol', 'Moneta', deployer).attach(addr.moneta),
    collybus: getContractFactory('lib/fiat/src/Collybus.sol', 'Collybus', deployer).attach(addr.collybus),
    publican: getContractFactory('lib/fiat/src/Publican.sol', 'Publican', deployer).attach(addr.publican),
    limes: getContractFactory('lib/fiat/src/Limes.sol', 'Limes', deployer).attach(addr.limes),
    collateralAuction: getContractFactory('lib/fiat/src/auctions/NoLossCollateralAuction.sol', 'NoLossCollateralAuction', deployer).attach(addr.collateralAuction),
    debtAuction: getContractFactory('lib/fiat/src/auctions/DebtAuction.sol', 'DebtAuction', deployer).attach(addr.debtAuction),
    surplusAuction: getContractFactory('lib/fiat/src/auctions/SurplusAuction.sol', 'SurplusAuction', deployer).attach(addr.surplusAuction),
    aer: getContractFactory('lib/fiat/src/Aer.sol', 'Aer', deployer).attach(addr.aer),
    tokenA: getContractFactory('src/test/utils/TestERC20.sol', 'TestERC20', deployer).attach(addr.tokenA),
    auctionGuard: getContractFactory('src/AuctionGuard.sol', 'AuctionGuard', deployer).attach(addr.auctionGuard),
    codexGuard: getContractFactory('src/CodexGuard.sol', 'CodexGuard', deployer).attach(addr.codexGuard),
    collybusGuard: getContractFactory('src/CollybusGuard.sol', 'CollybusGuard', deployer).attach(addr.collybusGuard),
    vaultGuard: getContractFactory('src/VaultGuard.sol', 'VaultGuard', deployer).attach(addr.vaultGuard)
  };
  return contracts;
}

module.exports = {
  encode4Byte, getContractFactory, deployViaVaultFactory, deployContract, send, sendAndWait, setupContracts, saveAddress
};
