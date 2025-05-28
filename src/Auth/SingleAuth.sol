// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

/// @title Single Authorization
/// @author jtriley2p
/// @notice Simple, single authorized address contract. Transition requires two steps; current admin
///         sends authorization to new admin, new admin accepts authorization. This requires the new
///         admin be capable of calling this contract before transition, preventing bricking.
abstract contract SingleAuth {
    /// @notice Logged on admin authority send.
    /// @param newAdmin New admin address.
    event SendAdmin(address indexed newAdmin);

    /// @notice Logged on admin authority acceptance.
    event ReceiveAdmin();

    /// @notice Current admin address.
    address public admin;

    /// @notice Pending admin address (non-zero only between sending and receiving admin).
    address public pendingAdmin;

    /// @notice Sends admin authority.
    /// @param newAdmin New admin address.
    function sendAdmin(address newAdmin) public {
        require(msg.sender == admin);

        pendingAdmin = newAdmin;

        emit SendAdmin(newAdmin);
    }

    /// @notice Receives admin authority.
    function receiveAdmin() public {
        require(msg.sender == pendingAdmin);

        admin = msg.sender;

        delete pendingAdmin;

        emit ReceiveAdmin();
    }
}
