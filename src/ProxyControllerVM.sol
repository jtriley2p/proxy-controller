// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import { Administrated } from "src/Auth/Administrated.sol";
import { Op, Ptr, readPtr } from "src/Lib/VM.sol";

enum Status {
    Queued,
    Cancelled,
    Deployed,
    RolledBack
}

struct Deployment {
    Status status;
    uint64 readyAt;
    bytes bytecode;
}

contract ProxyControllerVM is Administrated {
    using { readPtr } for bytes;

    /// @notice Logged on status update.
    /// @param index Deployment index.
    /// @param status New deployment status.
    event StatusUpdate(uint256 indexed index, Status status);

    Deployment[] public deployments;
    uint64 public timelock;

    function queue(
        bytes calldata bytecode
    ) public {
        uint256 index = deployments.length - 1;

        require(msg.sender == admin);
        require(deployments[index].status != Status.Queued);

        deployments.push(Deployment(Status.Queued, uint64(block.timestamp + timelock), bytecode));

        emit StatusUpdate(index, Status.Queued);
    }

    function cancel() public {
        uint256 index = deployments.length - 1;
        Deployment storage deployment = deployments[index];

        require(msg.sender == admin);
        require(deployment.status == Status.Queued);

        deployment.status = Status.Cancelled;

        emit StatusUpdate(index, Status.Cancelled);
    }

    function deploy() public {
        uint256 index = deployments.length - 1;
        Deployment storage deployment = deployments[index];

        require(msg.sender == admin);
        require(deployment.status == Status.Queued);
        require(deployment.readyAt <= block.timestamp);

        Ptr ptr = deployment.bytecode.readPtr();

        while (true) {
            Op op;
            
            (ptr, op) = ptr.readOp();

            if (op == Op.Halt) {
                break;
            } else if (op == Op.CreateProxy) {
                ptr = ptr.createProxy();
            } else if (op == Op.CreateBeaconProxy) {
                ptr = ptr.createBeaconProxy();
            } else if (op == Op.SetImplementation) {
                ptr = ptr.setImplementation();
            } else if (op == Op.SetBeacon) {
                ptr = ptr.setBeacon();
            } else if (op == Op.SetAdmin) {
                ptr = ptr.setAdmin();
            } else if (op == Op.Call) {
                ptr = ptr.runCall();
            } else if (op == Op.Create2) {
                ptr = ptr.runCreate2();
            } else {
                revert();
            }
        }
    }
}
