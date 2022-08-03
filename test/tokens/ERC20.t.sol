// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import {HuffConfig} from "foundry-huff/HuffConfig.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";

interface ERC20 {
    /* Metadata */
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /* Accessors */
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);

    /* EIP-2612 */
    // function nonces(address) external view returns (uint256);

    /* Mutators */
    function transfer(address, uint256) external;
    // function transferFrom(address, address, uint256) external;
    function approve(address, uint256) external;
    // function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external;
    function mint(address, uint256) external;
}

/// @author These tests have been adapted from Solmate and include additional coverage.
contract ERC20Test is Test {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    event NewOwner(address indexed oldOwner,address indexed newOwner);
    event NewPendingOwner(address indexed oldOwner, address indexed newOwner);

    IERC20Ownable token;

    address public bob = address(0xB0B);
    address public deployer = address(0xC0DE60D);

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    // "Token"
    string public constant NAME = "Token";
    bytes32 public constant META_NAME = bytes32(0x546f6b656e000000000000000000000000000000000000000000000000000000);
    uint256 public constant META_NAME_LENGTH = uint(0x5);

    // "TKN"
    string public constant SYMBOL = "TKN";
    bytes32 public constant META_SYMBOL = bytes32(0x544B4E0000000000000000000000000000000000000000000000000000000000);
    uint256 public constant META_SYMBOL_LENGTH = uint(0x3);

    // 18
    uint256 public constant DECIMALS = uint(0x12);

    function setUp() public {
        vm.startPrank(deployer);
        address tokenAddress = HuffDeployer.config()
            .with_bytes32_constant("META_NAME", META_NAME)
            .with_uint_constant("META_NAME_LENGTH", META_NAME_LENGTH)
            .with_bytes32_constant("META_SYMBOL", META_SYMBOL)
            .with_uint_constant("META_SYMBOL_LENGTH", META_SYMBOL_LENGTH)
            .with_uint_constant("META_DECIMALS", DECIMALS)
            .deploy("test/tokens/mocks/ERC20.mock");
        token = IERC20Ownable(tokenAddress);
        vm.stopPrank();
    }

    // SOLMATE ERC20 and OWNABLE tests below.  These are additional tests.

    function testNonPayable() public {
        vm.deal(address(this), 10 ether);

        // mint
        (bool success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.mint.selector, address(0xBEEF), 1e18)
        );
        assertFalse(success);
        // burn
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.burn.selector, address(0xBEEF), 1e18)
        );
        assertFalse(success);
        // approve
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(
                token.approve.selector,
                address(0xBEEF),
                1e18
            )
        );
        assertFalse(success);
        // transfer
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(
                token.transfer.selector,
                address(0xBEEF),
                1e18
            )
        );
        // transferFrom
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(
                token.transferFrom.selector,
                address(this),
                address(0xBEEF),
                1e18
            )
        );
        assertFalse(success);
        // name
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.name.selector, address(0xBEEF), 1e18)
        );
        assertFalse(success);
        // balanceOf
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.balanceOf.selector, address(0xBEEF))
        );
        assertFalse(success);
        // no data
        (success, ) = address(token).call{value: 1 ether}(abi.encode(0x0));
        assertFalse(success);
    }

    // SOLMATE TESTS - These have been modified as follows:
    //   1. Use forge-std/Test.sol instead of DS-Test+
    //   2. Instantiate the Huff contract within the tests as opposed to the abstract contract pattern used by Solmate
    //   3. Invariant tests changed to fuzzing.  (DappTools not supported here)
    //   4. Discontinue use of testFail (DappTools pattern) in favor of vm.expectRevert
    //   5. Additional coverage added to test all events
    //   6. Additional coverage added to test all instances of require()

    // SOLMATE ERC20 tests
    // https://github.com/transmissions11/solmate/blob/main/src/test/ERC20.t.sol
    function testMetadata() public {
        console.log(address(token));
        token.name();
        // assertEq(token.name(), NAME);
        // assertEq(token.symbol(), SYMBOL);
        // assertEq(token.decimals(), DECIMALS);
    }

    function testMint() public {
        token.mint(address(0xBEEF), 1e18);

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1e18);
        token.burn(address(0xBEEF), 0.9e18);

        assertEq(token.totalSupply(), 1e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(address(this), address(0xBEEF), 1e18);
        assertTrue(token.approve(address(0xBEEF), 1e18));
        assertEq(token.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        token.mint(address(this), 1e18);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), address(0xBEEF), 1e18);

        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom1() public {
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), 1e18);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(from, address(this)), type(uint256).max);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testFailTransferInsufficientBalance() public {
        token.mint(address(this), 0.9e18);
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), 0.9e18);

        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        token.mint(from, 0.9e18);

        vm.prank(from);
        token.approve(address(this), 1e18);

        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testMint(address from, uint256 amount) public {
        token.mint(from, amount);

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, 0, mintAmount);

        token.mint(from, mintAmount);
        token.burn(from, burnAmount);

        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address to, uint256 amount) public {
        assertTrue(token.approve(to, amount));

        assertEq(token.allowance(address(this), to), amount);
    }

    function testTransfer(address from, uint256 amount) public {
        token.mint(address(this), amount);

        assertTrue(token.transfer(from, amount));
        assertEq(token.totalSupply(), amount);

        if (address(this) == from) {
            assertEq(token.balanceOf(address(this)), amount);
        } else {
            assertEq(token.balanceOf(address(this)), 0);
            assertEq(token.balanceOf(from), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, 0, approval);

        address from = address(0xABCD);

        token.mint(from, amount);

        vm.prank(from);
        token.approve(address(this), approval);

        assertTrue(token.transferFrom(from, to, amount));
        assertEq(token.totalSupply(), amount);

        uint256 app = from == address(this) || approval == type(uint256).max
            ? approval
            : approval - amount;
        assertEq(token.allowance(from, address(this)), app);

        if (from == to) {
            assertEq(token.balanceOf(from), amount);
        } else {
            assertEq(token.balanceOf(from), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testFailBurnInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        token.mint(to, mintAmount);
        token.burn(to, burnAmount);
    }

    function testFailTransferInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        token.mint(address(this), mintAmount);
        token.transfer(to, sendAmount);
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, approval + 1, type(uint256).max);

        address from = address(0xABCD);

        token.mint(from, amount);

        vm.prank(from);
        token.approve(address(this), approval);

        token.transferFrom(from, to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        token.mint(from, mintAmount);

        vm.prank(from);
        token.approve(address(this), sendAmount);

        token.transferFrom(from, to, sendAmount);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.expectEmit(true, true, false, true);
        emit Approval(owner, address(0xCAFE), 1e18);
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function testFailPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            1,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testFailPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(
            owner,
            address(0xCAFE),
            1e18,
            block.timestamp + 1,
            v,
            r,
            s
        );
    }

    function testPermitPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp - 1
                        )
                    )
                )
            )
        );

        vm.expectRevert(bytes("PERMIT_DEADLINE_EXPIRED"));
        token.permit(
            owner,
            address(0xCAFE),
            1e18,
            block.timestamp - 1,
            v,
            r,
            s
        );
    }

    function testFailPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testInvalidSigner() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.expectRevert(bytes("INVALID_SIGNER"));
        token.permit(
            address(0xCAFE),
            address(0xCAFE),
            1e18,
            block.timestamp,
            v,
            r,
            s
        );
    }

    // SOLMATE OWNED tests
    // https://github.com/transmissions11/solmate/blob/main/src/test/Owned.t.sol

    function testSetPendingOwner() public {
        // assertEq(token.pendingOwner(), address(0x0));
        address owner = token.owner(); // TODO: Update when bug is fixed with HuffDeployer address
        address newOwner = address(0xBADBABE);

        vm.expectEmit(true, true, false, false);
        emit NewPendingOwner(owner, newOwner);

        vm.prank(owner);
        token.setPendingOwner(newOwner);
        assertEq(token.pendingOwner(), newOwner);
        vm.stopPrank();
    }

    function testAcceptOwnership() public {
        address owner = token.owner(); // TODO: Update when bug is fixed with HuffDeployer address
        address newOwner = address(0xBADBABE);

        vm.prank(owner);
        token.setPendingOwner(newOwner);
        assertEq(token.pendingOwner(), newOwner);
        vm.stopPrank();

        // calling acceptOwnership from unknown address reverts
        vm.expectRevert();
        token.acceptOwnership();

        // calling acceptOwnership emits event
        vm.prank(newOwner);
        vm.expectEmit(true, true, false, false);
        emit NewOwner(owner, newOwner);
        token.acceptOwnership();

        assertEq(token.owner(), newOwner);
        vm.stopPrank();
    }

    function testCallFunctionAsNonOwner(address owner) public {
        vm.assume(owner != token.owner());

        vm.expectRevert();
        token.setPendingOwner(owner);
    }
}
