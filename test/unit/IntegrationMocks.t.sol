// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { MockLiquidityAdapter } from "../../src/integration/MockLiquidityAdapter.sol";
import { MockUniswapV4Migrator } from "../../src/integration/MockUniswapV4Migrator.sol";
import {
    UniswapV4LiquidityMigrator,
    IExternalLiquidityMigrator
} from "../../src/integration/UniswapV4LiquidityMigrator.sol";

contract ExternalLiquidityMigratorMock is IExternalLiquidityMigrator {
    using SafeERC20 for IERC20;

    bytes32 public positionId = bytes32(uint256(1));
    address public lastToken;
    uint256 public lastTokenAmount;
    uint256 public lastEthAmount;
    bytes public lastPoolConfig;

    function setPositionId(bytes32 positionId_) external {
        positionId = positionId_;
    }

    function migrateGenesisPool(address token, uint256 tokenAmount, bytes calldata poolConfig)
        external
        payable
        returns (bytes32)
    {
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        lastToken = token;
        lastTokenAmount = tokenAmount;
        lastEthAmount = msg.value;
        lastPoolConfig = poolConfig;
        return positionId;
    }
}

contract IntegrationMocksTest is Test {
    FluxToken internal token;

    function setUp() public {
        token = new FluxToken(address(this));
        token.grantRole(token.MINTER_ROLE(), address(this));
    }

    function testMockLiquidityAdapterInitializesAndCompounds() public {
        MockLiquidityAdapter adapter = new MockLiquidityAdapter();
        uint256 positionId =
            adapter.initializePool{ value: 1 ether }(address(token), 2 ether, 1 ether, "");
        assertEq(positionId, 1);
        assertEq(adapter.nextPositionId(), 2);
        assertEq(adapter.liquidity(positionId), 1 ether);

        uint256 added = adapter.compound{ value: 0.5 ether }(positionId, 0.5 ether, "");
        assertEq(added, 0.5 ether);
        assertEq(adapter.liquidity(positionId), 1.5 ether);
    }

    function testMockLiquidityAdapterRevertsOnSlippageAndZeroPosition() public {
        MockLiquidityAdapter adapter = new MockLiquidityAdapter();
        vm.expectRevert();
        adapter.initializePool{ value: 1 ether }(address(token), 2 ether, 2 ether, "");

        adapter.initializePool{ value: 1 ether }(address(token), 2 ether, 0, "");
        vm.expectRevert();
        adapter.compound{ value: 1 ether }(0, 0, "");
        vm.expectRevert();
        adapter.compound{ value: 1 ether }(1, 2 ether, "");
    }

    function testMockUniswapV4Migrator() public {
        MockUniswapV4Migrator migrator = new MockUniswapV4Migrator();
        bytes32 positionId =
            migrator.bootstrapPool{ value: 1 ether }(address(token), 2 ether, 1 ether, "");
        assertTrue(positionId != bytes32(0));
        assertEq(migrator.nextPositionNonce(), 2);
        assertEq(migrator.seededLiquidity(positionId), 1 ether);

        vm.expectRevert();
        migrator.bootstrapPool{ value: 0.1 ether }(address(token), 1 ether, 1 ether, "");
    }

    function testUniswapV4LiquidityMigratorRequiresExternalMigrator() public {
        vm.expectRevert(UniswapV4LiquidityMigrator.MigratorNotConfigured.selector);
        new UniswapV4LiquidityMigrator(address(0));
    }

    function testUniswapV4LiquidityMigratorBootstraps() public {
        ExternalLiquidityMigratorMock externalMigrator = new ExternalLiquidityMigratorMock();
        UniswapV4LiquidityMigrator migrator =
            new UniswapV4LiquidityMigrator(address(externalMigrator));

        token.mint(address(this), 100 ether);
        token.approve(address(migrator), 100 ether);

        bytes32 positionId =
            migrator.bootstrapPool{ value: 1 ether }(address(token), 100 ether, 0, bytes("cfg"));
        assertEq(positionId, bytes32(uint256(1)));
        assertEq(token.balanceOf(address(externalMigrator)), 100 ether);
        assertEq(token.balanceOf(address(migrator)), 0);
        assertEq(externalMigrator.lastToken(), address(token));
        assertEq(externalMigrator.lastTokenAmount(), 100 ether);
        assertEq(externalMigrator.lastEthAmount(), 1 ether);
        assertEq(externalMigrator.lastPoolConfig(), bytes("cfg"));
    }

    function testUniswapV4LiquidityMigratorRejectsZeroPosition() public {
        ExternalLiquidityMigratorMock externalMigrator = new ExternalLiquidityMigratorMock();
        externalMigrator.setPositionId(bytes32(0));
        UniswapV4LiquidityMigrator migrator =
            new UniswapV4LiquidityMigrator(address(externalMigrator));

        token.mint(address(this), 1 ether);
        token.approve(address(migrator), 1 ether);
        vm.expectRevert(UniswapV4LiquidityMigrator.BootstrapFailed.selector);
        migrator.bootstrapPool{ value: 1 ether }(address(token), 1 ether, 0, "");
    }
}
