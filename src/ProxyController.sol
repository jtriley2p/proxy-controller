// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import { Administrated } from "src/Auth/Administrated.sol";
import { Administrated1967 } from "src/Auth/Administrated1967.sol";
import { ArchiveProxy1967 } from "src/Proxy/ArchiveProxy1967.sol";
import { BeaconArchiveProxy1967 } from "src/Proxy/BeaconArchiveProxy1967.sol";

// Proxy-Implementation Pair Structure
struct ProxyImpl {
    // ERC1967 Proxy
    ArchiveProxy1967 proxy;
    // Implementation Address
    address impl;
}

// Proxy-Beacon Pair Structure
struct ProxyBeacon {
    // ERC1967 Beacon Proxy
    BeaconArchiveProxy1967 proxy;
    // Beacon Address
    address beacon;
}

// Proxy-Admin Pair Structure
struct AdminChanges {
    // ERC1967 Proxy with Admin
    Administrated1967 proxy;
    // Admin Address
    address admin;
}

// Deployment Status
enum Status {
    Queued,
    Cancelled,
    Deployed,
    RolledBack
}

// Deployment Structure
struct Deployment {
    // Deployment Status
    Status status;
    // Timestamp at which deployment may execute.
    uint64 readyAt;
    // Salts for create2 proxy deployments.
    bytes32[] proxySalts;
    // Salts for create2 beacon proxy deployments.
    bytes32[] beaconProxySalts;
    // Proxy implementation pairs.
    ProxyImpl[] proxyImpls;
    // Proxy beacon pairs.
    ProxyBeacon[] proxyBeacons;
    // Proxy admin pairs.
    AdminChanges[] adminChanges;
}

/// @title Proxy Controller Contract
/// @author jtriley2p
/// @notice Deploys and upgrades proxies with a timelock-able queue. Deployments may be queued,
///         cancelled, executed, and/or rolled back.
/// @dev Deployments may only be cancelled if they are queued, but not deployed.
/// @dev Deployments may only be deployed if they are queued and the timelock as passed.
/// @dev Rollbacks move to the last successfully executed deployment.
contract ProxyController is Administrated {
    /// @notice Logged on status update.
    /// @param index Deployment index.
    /// @param status New deployment status.
    event StatusUpdate(uint256 indexed index, Status status);

    /// @notice Most recent deployment index.
    uint256 public lastDeploymentIndex;

    /// @notice Historical deployments array; facilitates rollbacks.
    Deployment[] public deployments;

    /// @notice Queues a new deployment. There MUST NOT be any currently queued deployments.
    /// @param timelock Seconds before deployment can be executed.
    /// @param proxySalts Salts for create2 proxy deployments.
    /// @param proxyImpls Pairs of addresses representing the proxy and respective implementation.
    function queue(
        uint64 timelock,
        bytes32[] calldata proxySalts,
        bytes32[] calldata proxyBeaconSalts,
        ProxyImpl[] calldata proxyImpls,
        ProxyBeacon[] calldata proxyBeacons,
        AdminChanges[] calldata adminChanges
    ) public {
        uint256 index = deployments.length - 1;

        require(msg.sender == admin);
        require(deployments[index].status != Status.Queued);

        deployments.push(
            Deployment(
                Status.Queued,
                uint64(block.timestamp + timelock),
                proxySalts,
                proxyBeaconSalts,
                proxyImpls,
                proxyBeacons,
                adminChanges
            )
        );

        emit StatusUpdate(index, Status.Queued);
    }

    /// @notice Cancels a deployment. The most recent deployment MUST have the queue status.
    function cancel() public {
        uint256 index = deployments.length - 1;
        Deployment storage deployment = deployments[index];

        require(msg.sender == admin);
        require(deployment.status == Status.Queued);

        deployment.status = Status.Cancelled;

        emit StatusUpdate(index, Status.Cancelled);
    }

    /// @notice Executes a deployment.
    /// @notice Deployment must be queued and timelock must have passed.
    /// @notice Deploys proxies, if any (via proxySalts), upgrades proxies, if any, then updates
    ///         deployment status and sets the last deployment index.
    function deploy() public {
        uint256 index = deployments.length - 1;
        Deployment storage deployment = deployments[index];

        require(msg.sender == admin);
        require(deployment.status == Status.Queued);
        require(deployment.readyAt <= block.timestamp);

        for (uint256 i; i < deployment.proxySalts.length; i++) {
            new ArchiveProxy1967{ salt: deployment.proxySalts[i] }();
        }

        for (uint256 i; i < deployment.beaconProxySalts.length; i++) {
            new BeaconArchiveProxy1967{ salt: deployment.beaconProxySalts[i] }();
        }

        for (uint256 i; i < deployment.proxyImpls.length; i++) {
            ArchiveProxy1967 proxy = deployment.proxyImpls[i].proxy;
            address impl = deployment.proxyImpls[i].impl;

            proxy.setImplementation(impl);
        }

        for (uint256 i; i < deployment.proxyBeacons.length; i++) {
            BeaconArchiveProxy1967 proxy = deployment.proxyBeacons[i].proxy;
            address beacon = deployment.proxyBeacons[i].beacon;

            proxy.setBeacon(beacon);
        }

        for (uint256 i; i < deployment.adminChanges.length; i++) {
            Administrated1967 proxy = deployment.adminChanges[i].proxy;
            address admin = deployment.adminChanges[i].admin;

            proxy.sendAdmin(admin);
        }

        deployment.status = Status.Deployed;
        lastDeploymentIndex = index;

        emit StatusUpdate(index, Status.Deployed);
    }

    /// @notice Rolls back a deployment.
    /// @notice Calls `rollback` on each proxy from most recent deployment.
    function rollBack() public {
        uint256 index = lastDeploymentIndex;
        Deployment storage lastDeployment = deployments[index];

        require(msg.sender == admin);

        for (uint256 i; i < lastDeployment.proxyImpls.length; i++) {
            lastDeployment.proxyImpls[i].proxy.rollBack();
        }

        lastDeployment.status = Status.RolledBack;

        emit StatusUpdate(index, Status.RolledBack);
    }
}
