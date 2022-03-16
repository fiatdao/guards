// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {IRelayer} from "delphi/relayer/IRelayer.sol";
import {IGuarded} from "fiat/interfaces/IGuarded.sol";
import {Delayed} from "./Delayed.sol";
import {BaseGuard} from "./BaseGuard.sol";

/// @title RelayerGuard
/// @notice Contract which guards parameter updates for a `Relayer`
contract RelayerGuard is BaseGuard {
    /// ======== Custom Errors ======== ///
    error RelayerGuard__isGuardForRelayer_cantCall(address relayer);
    
    constructor(
        address senatus,
        address guardian,
        uint256 delay
    ) BaseGuard(senatus, guardian, delay) {}

    /// ======== Storage ======== ///
    /// @notice See `BaseGuard`
    function isGuard() external view override returns (bool) {
        return true;
    }

    /// @notice Method that checks if the Guard has sufficient rights over a relayer.
    /// @param relayer Address of the relayer.
    function isGuardForRelayer(address relayer) public view returns (bool) {
        if (!IGuarded(relayer).canCall(IGuarded(relayer).ANY_SIG(), address(this))) revert RelayerGuard__isGuardForRelayer_cantCall(relayer);
        return true;
    }

    /// @notice Allows for a trusted third party to trigger an Relayer execute.
    /// The execute will update all oracles and will push the data to Collybus.
    /// @dev Can only be called by the guardian. After `delay` has passed it can be `execute`'d.
    /// @param relayer Address of the relayer that needs to whitelist the keeper
    /// @param keeperAddress Address of the keeper contract
    function setKeeperService(address relayer, address keeperAddress) external isDelayed {
        if (isGuardForRelayer(relayer))
            IGuarded(relayer).allowCaller(IRelayer.execute.selector, keeperAddress);
    }

    /// @notice Removes the permission to call execute on the Relayer.
    /// @dev Can only be called by the guardian.
    /// @param relayer Address of the relayer that needs to remove permissions for the keeper
    /// @param keeperAddress Address of the removed keeper contract
    function unsetKeeperService(address relayer, address keeperAddress) isGuardian external {
        if (isGuardForRelayer(relayer))
            IGuarded(relayer).blockCaller(IRelayer.execute.selector, keeperAddress);
    }
}
