// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

/// @title Post Deployment Check
/// @author jtriley2p
/// @notice Implementors must implement `check()` to run post-deployment checks.
abstract contract PostDeployment {
    function check() external virtual returns (bool success);
}
