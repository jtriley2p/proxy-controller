// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import { ArchiveProxy1967 } from "src/Proxy/ArchiveProxy1967.sol";
import { BeaconArchiveProxy1967 } from "src/Proxy/BeaconArchiveProxy1967.sol";

uint256 constant setImplementationSelector = 0xd784d42600000000000000000000000000000000000000000000000000000000;
uint256 constant setBeaconSelector = 0xd42afb5600000000000000000000000000000000000000000000000000000000;
uint256 constant setAdminSelector = 0x704b6c0200000000000000000000000000000000000000000000000000000000;

/*
operation ::=
    | (<createProxy> . <salt>)
    | (<createBeaconProxy> . <salt>)
    | (<setImplementation> . <proxy> . <impl>)
    | (<setBeacon> . <proxy> . <beacon>)
    | (<setAdmin> . <proxy> . <admin>)
    | (<call> . <target> . <value> . <payload>)
    | (<create2> . <salt> . <initcode>)
*/

enum Op {
    Halt,
    CreateProxy,
    CreateBeaconProxy,
    SetImplementation,
    SetBeacon,
    SetAdmin,
    Call,
    Create2
}

type Ptr is uint256;

using { readOp, createProxy, createBeaconProxy, setImplementation, setBeacon, setAdmin, runCall, runCreate2 } for Ptr global;

function readPtr(bytes memory bytecode) pure returns (Ptr ptr) {
    assembly {
        ptr := add(0x20, bytecode)
    }
}

function readOp(Ptr ptr) pure returns (Ptr newPtr, Op op) {
    assembly {
        newPtr := add(0x01, ptr)

        op := shr(0xf8, mload(ptr))
    }
}

function createProxy(Ptr ptr) returns (Ptr newPtr) {
    bytes32 salt;

    assembly {
        salt := mload(ptr)

        newPtr := add(0x20, ptr)
    }

    new ArchiveProxy1967{salt:salt}();
}

function createBeaconProxy(Ptr ptr) returns (Ptr newPtr) {
    bytes32 salt;

    assembly {
        salt := mload(ptr)

        newPtr := add(0x20, ptr)
    }

    new BeaconArchiveProxy1967{salt:salt}();
}

function setImplementation(Ptr ptr) returns (Ptr newPtr) {
    assembly {
        let proxy := shr(0x60, mload(ptr))

        ptr := add(0x14, ptr)

        let implementation := shr(0x60, mload(ptr))

        newPtr := add(0x14, ptr)

        mstore(0x00, setImplementationSelector)
        
        mstore(0x04, implementation)

        let ok := call(gas(), proxy, 0x00, 0x00, 0x24, 0x00, 0x00)

        if iszero(ok) {
            revert(0x00, 0x00)
        }
    }
}

function setBeacon(Ptr ptr) returns (Ptr newPtr) {
    assembly {
        let proxy := shr(0x60, mload(ptr))

        ptr := add(0x14, ptr)

        let beacon := shr(0x60, mload(ptr))

        newPtr := add(0x14, ptr)

        mstore(0x00, setBeaconSelector)
        
        mstore(0x04, beacon)

        let ok := call(gas(), proxy, 0x00, 0x00, 0x24, 0x00, 0x00)

        if iszero(ok) {
            revert(0x00, 0x00)
        }
    }
}

function setAdmin(Ptr ptr) returns (Ptr newPtr) {
    assembly {
        let proxy := shr(0x60, mload(ptr))

        ptr := add(0x14, ptr)

        let admin := shr(0x60, mload(ptr))

        newPtr := add(0x14, ptr)

        mstore(0x00, setAdminSelector)
        
        mstore(0x04, admin)

        let ok := call(gas(), proxy, 0x00, 0x00, 0x24, 0x00, 0x00)

        if iszero(ok) {
            revert(0x00, 0x00)
        }
    }
}

function runCall(Ptr ptr) returns (Ptr newPtr) {
    assembly {
        let target := shr(0x60, mload(ptr))

        ptr := add(0x14, ptr)

        let value := shr(0x80, mload(ptr))

        ptr := add(0x10, ptr)

        let len := shr(0xe0, mload(ptr))

        newPtr := add(0x04, ptr)

        let ok := call(gas(), target, value, newPtr, len, 0x00, 0x00)

        if iszero(ok) {
            revert(0x00, 0x00)
        }
    }
}

function runCreate2(Ptr ptr) returns (Ptr newPtr) {
    assembly {
        let value := shr(0x80, mload(ptr))

        ptr := add(0x10, ptr)

        let salt := mload(ptr)

        ptr := add(0x20, ptr)

        let len := shr(0xe0, mload(ptr))

        newPtr := add(0x04, ptr)

        let addr := create2(value, newPtr, len, salt)

        if iszero(addr) {
            revert(0x00, 0x00)
        }
    }
}

// TODO: add skips for rollback functionality
