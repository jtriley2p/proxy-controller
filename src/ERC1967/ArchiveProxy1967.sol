// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

bytes32 constant implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
bytes32 constant adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
bytes32 constant archiveSlot = 0xe5f5ff9e6908d8581103b80a34691dc6a53470d9a72154fc88f990b1e08ad7bc;

/// @title ArchiveProxy1967
/// @author jtriley2p
/// @notice Proxy contract implementing the ERC-1967 storage layout standard with an archive of
///         previous implementations.
/// @dev The only deviation from ERC-1967 is in the event definition for changing admin addresses.
///      It has been modified because the standard uses "SHOULD" instead of "MUST" and this
///      definition saves on gas and makes the indexing of admin transitions simpler.
contract ArchiveProxy1967 {
    /// @notice Logged on implementation upgrade.
    /// @param implementation New implementation contract address.
    event Upgraded(address indexed implementation);

    /// @notice Logged on implementation rollback.
    /// @param previous Previous implementation to which it rolled back.
    event RolledBack(address indexed previous);

    /// @notice Logged on admin change.
    /// @param admin New admin address.
    event AdminChanged(address indexed admin);

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

    /// @notice Returns admin address.
    function admin() public view returns (address adm) {
        assembly {
            adm := sload(adminSlot)
        }
    }

    /// @notice Upgrades the implementation contract address.
    /// @param newImplementation New implementation contract address.
    function upgrade(address newImplementation) public {
        require(msg.sender == admin());

        getArchive().push(newImplementation);

        assembly {
            sstore(implSlot, newImplementation)
        }

        emit Upgraded(newImplementation);
    }

    /// @notice Rolls back implementation to its previous state.
    /// @dev If there are no previous implementations, implementation is set to zero.
    function rollback() public {
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

    /// @notice Changes the admin address.
    /// @param newAdmin New admin address.
    function changeAdmin(address newAdmin) public {
        require(msg.sender == admin());

        assembly {
            sstore(adminSlot, newAdmin)
        }

        emit AdminChanged(newAdmin);
    }

    /// @notice Returns a storage pointer to the implementations archive.
    function getArchive() internal pure returns (address[] storage archive) {
        assembly {
            archive.slot := archiveSlot
        }
    }
}
