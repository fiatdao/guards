// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {DSToken} from "../utils/dapphub/DSToken.sol";
import {Hevm} from "../utils/Hevm.sol";

import {Codex} from "fiat/Codex.sol";
import {Publican} from "fiat/Publican.sol";
import {WAD} from "fiat/utils/Math.sol";

import {PublicanGuard} from "../../PublicanGuard.sol";

contract AerGuardTest is DSTest {
    Hevm hevm;

    Codex codex;
    Publican publican;

    PublicanGuard publicanGuard;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        codex = new Codex();
        publican = new Publican(address(codex));

        publicanGuard = new PublicanGuard(address(this), address(this), 1, address(publican));
        publican.allowCaller(publican.ANY_SIG(), address(publicanGuard));

        publican.init(address(1));
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
        publicanGuard.isGuard();

        publican.blockCaller(publican.ANY_SIG(), address(publicanGuard));
        assertTrue(!can_call(address(publicanGuard), abi.encodeWithSelector(publicanGuard.isGuard.selector)));
    }

    function test_setAer() public {
        assertTrue(
            !can_call(address(publicanGuard), abi.encodeWithSelector(publicanGuard.setAer.selector, address(1)))
        );

        bytes memory call = abi.encodeWithSelector(publicanGuard.setAer.selector, address(1));
        publicanGuard.schedule(call);

        assertTrue(
            !can_call(
                address(publicanGuard),
                abi.encodeWithSelector(
                    publicanGuard.execute.selector,
                    address(publicanGuard),
                    call,
                    block.timestamp + publicanGuard.delay()
                )
            )
        );

        hevm.warp(block.timestamp + publicanGuard.delay());
        publicanGuard.execute(address(publicanGuard), call, block.timestamp);
        assertEq(address(publican.aer()), address(1));
    }

    function test_setBaseInterest() public {
        publicanGuard.setBaseInterest(WAD);
        publicanGuard.setBaseInterest(1000000006341958396);
        assertEq(publican.baseInterest(), 1000000006341958396);

        assertTrue(
            !can_call(
                address(publicanGuard),
                abi.encodeWithSelector(publicanGuard.setBaseInterest.selector, 1000000006341958396 + 1)
            )
        );

        publicanGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(publicanGuard),
                abi.encodeWithSelector(publicanGuard.setBaseInterest.selector, 1000000006341958396)
            )
        );
    }

    function test_setInterestPerSecond() public {
        publicanGuard.setInterestPerSecond(address(1), WAD);
        publicanGuard.setInterestPerSecond(address(1), 1000000006341958396);
        (uint256 interestPerSecond, ) = publican.vaults(address(1));
        assertEq(interestPerSecond, 1000000006341958396);

        assertTrue(
            !can_call(
                address(publicanGuard),
                abi.encodeWithSelector(publicanGuard.setInterestPerSecond.selector, address(1), 1000000006341958396 + 1)
            )
        );

        publicanGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(publicanGuard),
                abi.encodeWithSelector(publicanGuard.setInterestPerSecond.selector, address(1), 1000000006341958396)
            )
        );
    }
}
