// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {DSToken} from "../utils/dapphub/DSToken.sol";
import {Hevm} from "../utils/Hevm.sol";

import {Collybus} from "fiat/Collybus.sol";
import {IRelayer} from "delphi/relayer/IRelayer.sol";
import {Relayer} from "delphi/relayer/Relayer.sol";

import {RelayerGuard} from "../../RelayerGuard.sol";

contract RelayerGuardTest is DSTest {
    Hevm hevm;

    Collybus collybus;
    Relayer relayer;
    RelayerGuard relayerGuard;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        collybus = new Collybus();
        // Create the relayer
        // The type parameter is not important because the execute flow is identical for all types.
        relayer = new Relayer(address(collybus),IRelayer.RelayerType.DiscountRate);

        relayerGuard = new RelayerGuard(address(this), address(this), 1);
        relayer.allowCaller(relayer.ANY_SIG(), address(relayerGuard));
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

    function test_isGuardForRelayer() public {
        relayerGuard.isGuardForRelayer(address(relayer));

        relayer.blockCaller(relayer.ANY_SIG(), address(relayerGuard));

        assertTrue(!can_call(address(relayerGuard), abi.encodeWithSelector(relayerGuard.isGuardForRelayer.selector,address(relayer))));
    }

    function test_setKeeperService() public {
        assertTrue(
            !can_call(address(relayerGuard), abi.encodeWithSelector(relayerGuard.setKeeperService.selector, address(relayer), address(1)))
        );

        bytes memory call = abi.encodeWithSelector(relayerGuard.setKeeperService.selector, address(relayer), address(1));
        relayerGuard.schedule(call);

        assertTrue(
            !can_call(
                address(relayerGuard),
                abi.encodeWithSelector(
                    relayerGuard.execute.selector,
                    address(relayerGuard),
                    call,
                    block.timestamp + relayerGuard.delay()
                )
            )
        );

        hevm.warp(block.timestamp + relayerGuard.delay());
        relayerGuard.execute(address(relayerGuard), call, block.timestamp);

        assertTrue(relayer.canCall(relayer.execute.selector, address(1)));
    }

    function test_unsetKeeperService() public {
        assertTrue(
            !can_call(address(relayerGuard), abi.encodeWithSelector(relayerGuard.setKeeperService.selector, address(relayer), address(1)))
        );

        bytes memory call = abi.encodeWithSelector(relayerGuard.setKeeperService.selector, address(relayer), address(1));
        relayerGuard.schedule(call);
        hevm.warp(block.timestamp + relayerGuard.delay());

        relayerGuard.execute(address(relayerGuard), call, block.timestamp);

        assertTrue(relayer.canCall(relayer.execute.selector, address(1)));
        relayerGuard.unsetKeeperService(address(relayer), address(1));
        assertTrue(!relayer.canCall(relayer.execute.selector, address(1)));
    }
}
