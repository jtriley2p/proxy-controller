// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import { Administrated } from "src/Auth/Administrated.sol";

/// @title Beacon Example
/// @author jtriley2p
/// @notice Minimalist beacon contract with single-authenticated address.
contract Beacon is Administrated {
    /// @notice Logged when implementation is set.
    /// @param newImplementation New implementation address.
    event ImplementationSet(address indexed newImplementation);

    /// @notice Logged on implementation rollback.
    /// @param previous Previous implementation to which it rolled back.
    event RolledBack(address indexed previous);

    /// @notice Returns the implementation address.
    address public implementation;

    /// @notice Returns the implementation archive.
    address[] public archive;

    /// @notice Sets the new implementation address.
    /// @param newImplementation New implementation address.
    function setImplementation(
        address newImplementation
    ) public {
        require(msg.sender == admin);

        implementation = newImplementation;

        archive.push(newImplementation);

        emit ImplementationSet(newImplementation);
    }

    /// @notice Rolls back implementation to previous state.
    /// @dev If there are no previous implementations, implementation is set to zero.
    function rollBack() public {
        require(msg.sender == admin);

        uint256 archiveLen = archive.length;
        address previous;

        if (archiveLen > 0) {
            previous = archive[archiveLen - 1];
            archive.pop();
        } else {
            previous = address(0x00);
        }

        implementation = previous;

        emit RolledBack(previous);
    }
}
