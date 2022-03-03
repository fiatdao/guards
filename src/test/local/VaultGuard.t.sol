// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {DSToken} from "../utils/dapphub/DSToken.sol";
import {Hevm} from "../utils/Hevm.sol";

import {Codex} from "fiat/Codex.sol";
import {Publican} from "fiat/Publican.sol";
import {Limes} from "fiat/Limes.sol";
import {Collybus} from "fiat/Collybus.sol";
import {NoLossCollateralAuction} from "fiat/auctions/NoLossCollateralAuction.sol";
import {LinearDecrease} from "fiat/auctions/PriceCalculator.sol";
import {Vault20} from "fiat/Vault.sol";
import {WAD} from "fiat/utils/Math.sol";

import {VaultGuard, PriceCalculatorFactory} from "../../VaultGuard.sol";

contract VaultGuardTest is DSTest {
    Hevm hevm;

    Codex codex;
    Publican publican;
    Limes limes;
    Collybus collybus;
    NoLossCollateralAuction collateralAuction;
    DSToken token;
    Vault20 vault;
    PriceCalculatorFactory priceCalculatorFactory;

    VaultGuard vaultGuard;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        codex = new Codex();
        publican = new Publican(address(codex));
        limes = new Limes(address(codex));
        collybus = new Collybus();
        collateralAuction = new NoLossCollateralAuction(address(codex), address(limes));
        token = new DSToken("");
        priceCalculatorFactory = new PriceCalculatorFactory();

        vaultGuard = new VaultGuard(
            address(this),
            address(this),
            1,
            address(codex),
            address(publican),
            address(limes),
            address(collybus),
            address(collateralAuction),
            address(priceCalculatorFactory)
        );
        codex.allowCaller(codex.ANY_SIG(), address(vaultGuard));
        publican.allowCaller(publican.ANY_SIG(), address(vaultGuard));
        limes.allowCaller(limes.ANY_SIG(), address(vaultGuard));
        collybus.allowCaller(collybus.ANY_SIG(), address(vaultGuard));
        collateralAuction.allowCaller(collateralAuction.ANY_SIG(), address(vaultGuard));

        vault = new Vault20(address(codex), address(token), address(collybus));
        vault.allowCaller(vault.ANY_SIG(), address(vaultGuard));
    }

    function try_call(address addr, bytes memory data) public returns (bool) {
        bytes memory _data = data;
        assembly {
            let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }

    function can_call(address addr, bytes memory data) public returns (bool) {
        bytes memory call = abi.encodeWithSignature("try_call(address,bytes)", addr, data);
        (bool ok, bytes memory success) = address(this).call(call);
        ok = abi.decode(success, (bool));
        if (ok) return true;
        return false;
    }

    function test_isGuard() public {
        vaultGuard.isGuard();

        codex.blockCaller(codex.ANY_SIG(), address(vaultGuard));
        assertTrue(!can_call(address(vaultGuard), abi.encodeWithSelector(vaultGuard.isGuard.selector)));
    }

    function test_setVault() public {
        // can't call
        vault.blockCaller(vault.ANY_SIG(), address(vaultGuard));
        assertTrue(
            !can_call(
                address(vaultGuard),
                abi.encodeWithSelector(
                    vaultGuard.setVault.selector,
                    address(vault),
                    address(1),
                    bytes32("LinearDecrease"),
                    1,
                    1,
                    1,
                    1,
                    1,
                    1,
                    WAD,
                    1
                )
            )
        );

        // success
        vault.allowCaller(vault.ANY_SIG(), address(vaultGuard));
        vaultGuard.setVault(address(vault), address(1), bytes32("LinearDecrease"), 1, 1, 1, 1, 1, 1, WAD, 1);

        // already init
        assertTrue(
            !can_call(
                address(vaultGuard),
                abi.encodeWithSelector(
                    vaultGuard.setVault.selector,
                    address(vault),
                    address(1),
                    bytes32("LinearDecrease"),
                    1,
                    1,
                    1,
                    1,
                    1,
                    1,
                    WAD,
                    1
                )
            )
        );

        // not guardian
        Vault20 vault2 = new Vault20(address(codex), address(token), address(collybus));
        vault2.allowCaller(vault2.ANY_SIG(), address(vaultGuard));
        vaultGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(vaultGuard),
                abi.encodeWithSelector(
                    vaultGuard.setVault.selector,
                    address(vault2),
                    address(1),
                    bytes32("LinearDecrease"),
                    1,
                    1,
                    1,
                    1,
                    1,
                    1,
                    WAD,
                    1
                )
            )
        );
    }

    function test_lockVault() public {
        vaultGuard.setGuardian(address(0));
        assertTrue(
            !can_call(address(vaultGuard), abi.encodeWithSelector(vaultGuard.lockVault.selector, address(vault)))
        );

        vaultGuard.setGuardian(address(this));
        vaultGuard.lockVault(address(vault));
    }
}
