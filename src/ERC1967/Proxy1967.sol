// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

bytes32 constant implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
bytes32 constant adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

/// @title Proxy1967
/// @author jtriley2p
/// @notice Proxy contract implementing the ERC-1967 storage layout standard.
/// @dev The only deviation from ERC-1967 is in the event definition for changing admin addresses.
///      It has been modified because the standard uses "SHOULD" instead of "MUST" and this
///      definition saves on gas and makes the indexing of admin transitions simpler.
contract Proxy1967 {
    /// @notice Logged on implementation upgrade.
    /// @param implementation New implementation contract address.
    event Upgraded(address indexed implementation);

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

        assembly {
            sstore(implSlot, newImplementation)
        }

        emit Upgraded(newImplementation);
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
}
