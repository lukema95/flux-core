// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TestBase } from "../TestBase.sol";
import { AssetRegistry } from "../../src/core/AssetRegistry.sol";
import { CreditManager } from "../../src/core/CreditManager.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";
import { LiquidityVault } from "../../src/vault/LiquidityVault.sol";
import { BalanceVault } from "../../src/vault/BalanceVault.sol";
import { ProtocolVault } from "../../src/vault/ProtocolVault.sol";
import { RewardAssetRegistry } from "../../src/economic/RewardAssetRegistry.sol";
import { FluxAccount } from "../../src/account/FluxAccount.sol";
import { MockUniswapV4Migrator } from "../../src/integration/MockUniswapV4Migrator.sol";
import { IFluxToken, IBalanceEngine, IRewardStrategy } from "../../src/interfaces/IFlux.sol";

contract ERC20RewardStrategy is IRewardStrategy {
    IERC20 public immutable token;

    constructor(IERC20 token_) {
        token = token_;
    }

    function inputAsset() external view returns (address) {
        return address(token);
    }

    function outputAsset() external view returns (address) {
        return address(token);
    }

    function execute(uint256 amountIn, uint256, bytes calldata)
        external
        payable
        returns (uint256 amountOut)
    {
        token.transfer(msg.sender, amountIn);
        return amountIn;
    }
}

/// @notice Tests for edge paths that are hard to reach through the main flows.
contract EdgeCasesTest is TestBase {
    function testUnpauseAndInitialFTPopPath() public {
        conversion.setPaused(true);
        assertTrue(conversion.paused());
        conversion.setPaused(false);
        assertFalse(conversion.paused());

        assertEq(conversion.ftAssetCount(), 5_000);
        flux.mint(alice, conversion.UNIT());
        IBalanceEngine.Quote memory q = conversion.preview(true);
        vm.deal(alice, q.fee);
        vm.prank(alice);
        uint256 tokenId = conversion.ftToNFT{ value: q.fee }(123);

        assertEq(nft.assetOf(tokenId), registry.MAX_ASSETS());
        assertEq(conversion.ftAssetCount(), 4_999);
    }

    function testAssetRegistryRejectsInvalidGenesisTransitions() public {
        registry.grantRole(registry.CONTROLLER_ROLE(), address(this));
        vm.expectRevert(AssetRegistry.InvalidGenesisTransition.selector);
        registry.transition(
            1, AssetRegistry.AssetState.Credit, AssetRegistry.AssetState.GenesisNFT, 1, false
        );
        vm.expectRevert(AssetRegistry.InvalidGenesisTransition.selector);
        registry.transition(
            1, AssetRegistry.AssetState.Credit, AssetRegistry.AssetState.NFT, 1, true
        );
    }

    function testRewardStrategyERC20DepositAndUnpause() public {
        ERC20RewardStrategy adapter = new ERC20RewardStrategy(IERC20(address(flux)));
        bytes32 id = keccak256("ERC20");
        rewardStrategy.setStrategy(id, adapter);
        rewardAssets.registerAsset(address(flux), RewardAssetRegistry.AssetType.ERC20, address(0));

        uint256 tokenId = _mintGenesis(alice, 61);
        flux.mint(address(adapter), 100 ether);

        rewardStrategy.setPaused(true);
        vm.expectRevert();
        rewardStrategy.holdNative();
        rewardStrategy.setPaused(false);

        uint256 out = rewardStrategy.execute(id, 100 ether, 100 ether, "");
        assertEq(out, 100 ether);
        assertEq(genesisVault.pending(tokenId, address(flux)), 100 ether);
    }

    function testVaultValidation() public {
        vm.expectRevert(BalanceVault.EpochBudgetExceeded.selector);
        balanceVault.setDailyReleaseBps(10_001);

        vm.expectRevert(ProtocolVault.InvalidRecipient.selector);
        new ProtocolVault(address(this), address(0));
        vm.expectRevert(ProtocolVault.InvalidRecipient.selector);
        protocolVault.setRecipient(address(0));
    }

    function testFluxAccountRejectsZeroTarget() public {
        uint256 tokenId = _mintGenesis(alice, 62);
        address tba = accountManager.ensureAccount(tokenId);
        vm.prank(alice);
        vm.expectRevert(FluxAccount.ExecutionFailed.selector);
        FluxAccount(payable(tba)).execute(address(0), 0, "");
    }

    function testAuctionCheckpointUpdateAndPreview() public {
        CreditManager credits = new CreditManager(address(this));
        LiquidityVault liquidity = new LiquidityVault(address(this));
        GenesisAuction auction = new GenesisAuction(
            address(this),
            credits,
            IFluxToken(address(flux)),
            new MockUniswapV4Migrator(),
            liquidity
        );
        credits.grantRole(credits.ISSUER_ROLE(), address(auction));
        flux.grantRole(flux.MINTER_ROLE(), address(auction));
        liquidity.grantRole(liquidity.GENESIS_REGISTRAR_ROLE(), address(auction));

        uint64 start = uint64(block.timestamp);
        uint64 end = start + 2 days;
        auction.createAuction(start, end);

        vm.deal(alice, 20_000 ether);
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);

        vm.warp(start + 1 days);
        auction.checkpoint();
        assertGt(auction.totalCreditsAllocated(), 0);

        vm.prank(alice);
        vm.expectRevert(GenesisAuction.InvalidBid.selector);
        auction.bid{ value: 1 ether }(1 ether);

        vm.warp(end);
        auction.finalize();
        assertEq(auction.clearingPricePreview(), auction.clearingPrice());
    }
}
