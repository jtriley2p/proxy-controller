// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import { Administrated1967 } from "src/Auth/Administrated1967.sol";

/// @title Recovery Implementation
/// @author jtriley2p
/// @notice Temporary recovery implementation contract for proxies in an error state.
/// @dev Makes arbitrary calls and writes arbitrary storage. Admin is stored in the standard
///      ERC-1967 slot.
contract Recovery is Administrated1967 {
    /// @notice Logged when calls are run.
    event CallsRun();

    /// @notice Logged when slots are written.
    event SlotsWritten();

    /// @notice Runs external calls in batch.
    /// @param targets Array of target contracts.
    /// @param values Array of call values.
    /// @param payloads Array of call payloads.
    /// @dev throws if any fail.
    function runCalls(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads
    ) public payable {
        uint256 len = targets.length;
        bool ok = true;

        require(len == values.length && len == payloads.length);

        for (uint256 i; i < len; i++) {
            (bool success,) = targets[i].call{ value: values[i] }(payloads[i]);
            ok = ok && success;
        }

        require(ok);

        emit CallsRun();
    }

    /// @notice Writes storage slots in batch.
    /// @param slots Storage slot indices.
    /// @param values Values to write to storage.
    function writeSlots(bytes32[] calldata slots, bytes32[] calldata values) public {
        uint256 len = slots.length;

        require(len == values.length);

        for (uint256 i; i < len; i++) {
            bytes32 slot = slots[i];
            bytes32 value = values[i];

            assembly {
                sstore(slot, value)
            }
        }

        emit SlotsWritten();
    }
}
