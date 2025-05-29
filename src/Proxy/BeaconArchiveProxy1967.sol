// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

bytes32 constant adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
bytes32 constant beaconSlot = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
bytes32 constant archiveSlot = 0x6d0a4a697ff0ac6a742f5fd4ef4635463f282c015f1b33be5ff5077e69199088;

/// @title Beacon Proxy
/// @author jtriley2p
/// @notice Beacon contract for ERC-1967 BeaconProxy contracts to call for the implementation
///         address.
contract BeaconArchiveProxy1967 {
    /// @notice Logged on beacon set.
    /// @param beacon New beacon contract address.
    /// @dev Note that this is when the beacon itself changes, not the address it returns.
    event BeaconSet(address indexed beacon);

    /// @notice Logged on implementation rollback.
    /// @param previous Previous implementation to which it rolled back.
    event BeaconRolledBack(address indexed previous);

    /// @notice Logged on admin change.
    /// @param admin New admin address.
    event AdminChanged(address indexed admin);

    constructor() {
        assembly {
            sstore(adminSlot, caller())
        }

        emit AdminChanged(msg.sender);
    }

    /// @notice Returns admin address.
    function admin() public view returns (address adm) {
        assembly {
            adm := sload(adminSlot)
        }
    }

    /// @notice Returns beacon address.
    function beacon() public view returns (address bcn) {
        assembly {
            bcn := sload(beaconSlot)
        }
    }

    /// @notice Sets beacon contract address.
    /// @param newBeacon New beacon contract address.
    /// @dev Note that this changes the beacon itself changes, not the address it returns.
    function setBeacon(address newBeacon) public {
        require(msg.sender == admin());

        getArchive().push(newBeacon);

        assembly {
            sstore(beaconSlot, newBeacon)
        }

        emit BeaconSet(newBeacon);
    }

    /// @notice Rolls back beacon to its previous state.
    /// @dev If there are no previous beacon, beacon is set to zero.
    function rollBackBeacon() public {
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
            sstore(beaconSlot, previous)
        }

        emit BeaconRolledBack(previous);
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
    /// @dev Slot is keccak256("proxy.archive") - 1
    function getArchive() internal pure returns (address[] storage archive) {
        assembly {
            archive.slot := archiveSlot
        }
    }
}
