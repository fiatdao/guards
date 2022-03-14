// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {IRelayer} from "delphi/relayer/IRelayer.sol";
import {Delayed} from "./Delayed.sol";
import {BaseGuard} from "./BaseGuard.sol";

/// @title RelayerGuard
/// @notice Contract which guards parameter updates for a `Relayer`
contract RelayerGuard is BaseGuard {
    /// ======== Custom Errors ======== ///

    error RelayerGuard__isGuard_cantCall();

    /// ======== Storage ======== ///

    /// @notice Address of the Relayer
    Relayer public immutable relayer;

    constructor(
        address senatus,
        address guardian,
        uint256 delay,
        address relayer_
    ) BaseGuard(senatus, guardian, delay) {
        relayer = Relayer(relayer_)
    }

    /// @notice See `BaseGuard`
    function isGuard() external view override returns (bool) {
        if (!relayer.canCall(relayer.ANY_SIG(), address(this))) revert RelayerGuard__isGuard_cantCall();
        return true;
    }

    /// @notice Allows for a trusted third party to trigger an Relayer execute.
    /// The execute will update all oracles and will push the data to Collybus.
    /// @dev Can only be called by the guardian. After `delay` has passed it can be `execute`'d.
    /// @param keeperAddress See. Collybus
    function setKeeperService(address keeperAddress) external isDelayed {
        relayer.allowCaller(Relayer.execute.selector, keeperAddress);
    }

    /// @notice Removes the permission to call execute on the Relayer.
    /// @dev Can only be called by the guardian. After `delay` has passed it can be `execute`'d.
    /// @param keeperAddress See. Collybus
    function unsetKeeperService(address keeperAddress) external isDelayed {
        relayer.allowCaller(Relayer.execute.selector, keeperAddress);
    }
}
