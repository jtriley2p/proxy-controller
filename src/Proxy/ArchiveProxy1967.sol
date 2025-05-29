// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import { Administrated1967, adminSlot } from "src/Auth/Administrated1967.sol";

bytes32 constant implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
bytes32 constant archiveSlot = 0x6d0a4a697ff0ac6a742f5fd4ef4635463f282c015f1b33be5ff5077e69199088;

/// @title ERC-1967 Proxy with Implementation Archive
/// @author jtriley2p
/// @notice Proxy contract implementing the ERC-1967 storage layout standard with an archive of
///         previous implementations.
/// @dev The only deviation from ERC-1967 is in the event definition for changing admin addresses.
///      It has been modified because the standard uses "SHOULD" instead of "MUST" and this
///      definition saves on gas and makes the indexing of admin transitions simpler.
contract ArchiveProxy1967 is Administrated1967 {
    /// @notice Logged on implementation set.
    /// @param implementation New implementation contract address.
    event ImplementationSet(address indexed implementation);

    /// @notice Logged on implementation rollback.
    /// @param previous Previous implementation to which it rolled back.
    event RolledBack(address indexed previous);

    constructor() {
        assembly {
            sstore(adminSlot, caller())
        }

        emit AdminChanged(msg.sender);
    }

    /// @notice Returns implementation contract address.
    function implementation() public view returns (address impl) {
        assembly {
            impl := sload(implSlot)
        }
    }

    /// @notice Sets the implementation contract address.
    /// @param newImplementation New implementation contract address.
    function setImplementation(address newImplementation) public {
        require(msg.sender == admin());

        getArchive().push(newImplementation);

        assembly {
            sstore(implSlot, newImplementation)
        }

        emit ImplementationSet(newImplementation);
    }

    /// @notice Rolls back implementation to its previous state.
    /// @dev If there are no previous implementations, implementation is set to zero.
    function rollBack() public {
        require(msg.sender == admin());

        address[] storage archive = getArchive();

        uint256 archiveLen = archive.length;
        address previous;

        if (archiveLen > 0) {
            previous = archive[archiveLen - 1];
            archive.pop();
        } else {
            previous = address(0x00);
        }

        assembly {
            sstore(implSlot, previous)
        }

        emit RolledBack(previous);
    }

    /// @notice Returns a storage pointer to the implementations archive.
    /// @dev Slot is keccak256("proxy.archive") - 1
    function getArchive() internal pure returns (address[] storage archive) {
        assembly {
            archive.slot := archiveSlot
        }
    }
}
